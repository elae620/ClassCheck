-- =====================================================================
-- ClassCheck — 007 : Sprint 2
--   auto-déclarations, réclamations (Storage), corrections manuelles,
--   notifications, statistiques, gestion des comptes et des emplois du temps.
-- Toutes les écritures sensibles passent par des fonctions (RPC) qui
-- fournissent le motif à l'audit via set_config('app.motif', …).
-- Réexécutable.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Schéma
-- ---------------------------------------------------------------------
-- Absence justifiée (certificat accepté, auto-déclaration validée) :
-- elle reste une absence mais ne compte plus pour le seuil d'exclusion.
alter table public.presences add column if not exists justifiee boolean not null default false;

-- Une seule réclamation active par présence.
create unique index if not exists uq_reclamation_active
  on public.reclamations(presence_id) where statut in ('en_attente', 'transmise');
create index if not exists idx_reclamations_etudiant on public.reclamations(etudiant_id, created_at desc);
create index if not exists idx_autodecl_seance on public.auto_declarations(seance_id);

-- Notifications en temps réel (cloche de l'étudiant).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

-- L'audit des présences couvre aussi le passage en « justifiée ».
create or replace function public.trg_audit_presences()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_motif text := public._motif_courant();
begin
  if new.statut is distinct from old.statut or new.justifiee is distinct from old.justifiee then
    if v_motif is null then
      raise exception 'motif_obligatoire';
    end if;
    new.updated_at := now();
    insert into public.audit_log (acteur_id, action, table_cible, cible_id, details, motif)
    values (auth.uid(), 'correction_presence', 'presences', new.id::text,
            jsonb_build_object('seance_id', new.seance_id, 'etudiant_id', new.etudiant_id,
                               'ancien', old.statut, 'nouveau', new.statut,
                               'justifiee', new.justifiee, 'methode', new.methode),
            v_motif);
  end if;
  return new;
end $$;
revoke execute on function public.trg_audit_presences() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------
create or replace function public._notifier(p_dest uuid, p_titre text, p_message text, p_type text)
returns void language sql security definer set search_path = public as $$
  insert into public.notifications (destinataire_id, titre, message, type)
  values (p_dest, p_titre, p_message, p_type)
$$;
revoke execute on function public._notifier(uuid, text, text, text) from public, anon, authenticated;

-- Nombre d'absences NON justifiées d'un étudiant dans un cours.
create or replace function public._absences_cours(p_etudiant uuid, p_cours uuid)
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int
  from public.presences p join public.seances s on s.id = p.seance_id
  where p.etudiant_id = p_etudiant and s.cours_id = p_cours
    and p.statut = 'absent' and not p.justifiee
$$;
revoke execute on function public._absences_cours(uuid, uuid) from public, anon, authenticated;

-- Alerte « seuil d'absences proche / atteint » à chaque nouvelle absence.
create or replace function public.trg_alerte_absences()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_cours record;
  v_seuil int;
  v_nb int;
begin
  if new.statut <> 'absent' or new.justifiee then return null; end if;
  if tg_op = 'UPDATE' and old.statut = 'absent' and not old.justifiee then return null; end if;

  select c.id, coalesce(c.nom_court, c.nom) as nom into v_cours
  from public.seances s join public.cours c on c.id = s.cours_id where s.id = new.seance_id;
  select seuil_exclusion into v_seuil from public.regles where id = 1;
  v_nb := public._absences_cours(new.etudiant_id, v_cours.id);

  if v_nb >= v_seuil then
    perform public._notifier(new.etudiant_id, 'Seuil d''absences atteint',
      format('%s absences sur %s autorisées en %s', v_nb, v_seuil, v_cours.nom), 'seuil');
  elsif v_nb = v_seuil - 1 then
    perform public._notifier(new.etudiant_id, 'Seuil d''absences proche',
      format('%s absences sur %s autorisées en %s', v_nb, v_seuil, v_cours.nom), 'seuil');
  end if;
  return null;
end $$;
revoke execute on function public.trg_alerte_absences() from public, anon, authenticated;

drop trigger if exists alerte_absences on public.presences;
create trigger alerte_absences
  after insert or update of statut, justifiee on public.presences
  for each row execute function public.trg_alerte_absences();

-- ---------------------------------------------------------------------
-- Storage : justificatifs (bucket privé, dossier = id de l'étudiant)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('justificatifs', 'justificatifs', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists justificatifs_insert on storage.objects;
create policy justificatifs_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'justificatifs' and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists justificatifs_select on storage.objects;
create policy justificatifs_select on storage.objects for select to authenticated using (
  bucket_id = 'justificatifs' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.est_directeur()
    or exists (
      select 1 from public.reclamations r join public.presences p on p.id = r.presence_id
      where r.justificatif_url = storage.objects.name and public.est_enseignant_seance(p.seance_id)
    )
  )
);

-- ---------------------------------------------------------------------
-- Enseignant / directeur : correction manuelle (motif obligatoire)
-- ---------------------------------------------------------------------
create or replace function public.corriger_presence(
  p_seance_id uuid, p_etudiant_id uuid, p_statut text, p_motif text
) returns json language plpgsql security definer set search_path = public as $$
declare
  v_p public.presences;
  v_classe text;
begin
  if not (public.est_enseignant_seance(p_seance_id) or public.est_directeur()) then
    raise exception 'acces_refuse';
  end if;
  if p_statut not in ('present', 'absent', 'retard') then raise exception 'statut_invalide'; end if;
  if nullif(trim(p_motif), '') is null then raise exception 'motif_obligatoire'; end if;

  select c.classe into v_classe from public.seances s join public.cours c on c.id = s.cours_id
  where s.id = p_seance_id;
  if not exists (select 1 from public.profils where id = p_etudiant_id and role = 'etudiant'
                 and classe = v_classe) then
    raise exception 'non_inscrit';
  end if;

  perform set_config('app.motif', trim(p_motif), true);
  update public.presences
  set statut = p_statut, methode = 'manuel', valide_par = auth.uid(),
      justifiee = case when p_statut = 'absent' then justifiee else false end,
      pointe_a = coalesce(pointe_a, case when p_statut <> 'absent' then now() end)
  where seance_id = p_seance_id and etudiant_id = p_etudiant_id
  returning * into v_p;

  if not found then
    insert into public.presences (seance_id, etudiant_id, statut, methode, valide_par, pointe_a)
    values (p_seance_id, p_etudiant_id, p_statut, 'manuel', auth.uid(),
            case when p_statut <> 'absent' then now() end)
    returning * into v_p;
    insert into public.audit_log (acteur_id, action, table_cible, cible_id, details, motif)
    values (auth.uid(), 'correction_presence', 'presences', v_p.id::text,
            jsonb_build_object('seance_id', p_seance_id, 'etudiant_id', p_etudiant_id,
                               'ancien', null, 'nouveau', p_statut, 'methode', 'manuel'),
            trim(p_motif));
  end if;
  return row_to_json(v_p);
end $$;

-- ---------------------------------------------------------------------
-- Enseignant : validation / refus d'une auto-déclaration
-- ---------------------------------------------------------------------
create or replace function public.traiter_auto_declaration(
  p_id uuid, p_valider boolean, p_motif text default null
) returns json language plpgsql security definer set search_path = public as $$
declare
  v public.auto_declarations;
  v_cours text;
  v_date date;
  v_motif text;
begin
  select * into v from public.auto_declarations where id = p_id for update;
  if not found then raise exception 'introuvable'; end if;
  if not (public.est_enseignant_seance(v.seance_id) or public.est_directeur()) then
    raise exception 'acces_refuse';
  end if;
  if v.statut <> 'en_attente' then raise exception 'deja_traitee'; end if;

  v_motif := coalesce(nullif(trim(p_motif), ''),
                      case when p_valider then 'Auto-déclaration validée : ' || v.motif
                           else 'Auto-déclaration refusée' end);
  perform set_config('app.motif', v_motif, true);

  update public.auto_declarations
  set statut = case when p_valider then 'validee' else 'refusee' end, traite_par = auth.uid()
  where id = p_id returning * into v;

  if p_valider then
    if v.type = 'retard' then
      insert into public.presences (seance_id, etudiant_id, statut, methode, valide_par, pointe_a)
      values (v.seance_id, v.etudiant_id, 'retard', 'auto_declaration', auth.uid(), now())
      on conflict (seance_id, etudiant_id) do update
        set statut = 'retard', methode = 'auto_declaration', valide_par = auth.uid(), justifiee = false;
    else
      insert into public.presences (seance_id, etudiant_id, statut, methode, valide_par, justifiee)
      values (v.seance_id, v.etudiant_id, 'absent', 'auto_declaration', auth.uid(), true)
      on conflict (seance_id, etudiant_id) do update
        set statut = 'absent', methode = 'auto_declaration', valide_par = auth.uid(), justifiee = true;
    end if;
  end if;

  select coalesce(c.nom_court, c.nom), s.date into v_cours, v_date
  from public.seances s join public.cours c on c.id = s.cours_id where s.id = v.seance_id;
  perform public._notifier(v.etudiant_id,
    case when p_valider then 'Auto-déclaration validée' else 'Auto-déclaration refusée' end,
    format('Votre %s du %s (%s) %s',
           case when v.type = 'retard' then 'retard' else 'absence' end,
           to_char(v_date, 'DD/MM'), v_cours,
           case when p_valider then 'est enregistré(e).' else 'n''a pas été acceptée.' end),
    'auto_declaration');
  return row_to_json(v);
end $$;

-- ---------------------------------------------------------------------
-- Réclamations
--   enseignant : en_attente → acceptee | refusee | transmise
--   étudiant   : refusee → transmise (recours auprès du directeur)
--   directeur  : en_attente | transmise → acceptee | refusee (décision finale)
-- ---------------------------------------------------------------------
create or replace function public.traiter_reclamation(
  p_id uuid, p_decision text, p_commentaire text
) returns json language plpgsql security definer set search_path = public as $$
declare
  v public.reclamations;
  v_seance uuid;
  v_dir boolean := public.est_directeur();
  v_cours text;
  v_date date;
  v_titre text;
  v_msg text;
begin
  select r.* into v from public.reclamations r where r.id = p_id for update;
  if not found then raise exception 'introuvable'; end if;
  select p.seance_id into v_seance from public.presences p where p.id = v.presence_id;
  if not (v_dir or public.est_enseignant_seance(v_seance)) then raise exception 'acces_refuse'; end if;
  if p_decision not in ('acceptee', 'refusee', 'transmise') then raise exception 'decision_invalide'; end if;
  if nullif(trim(p_commentaire), '') is null then raise exception 'motif_obligatoire'; end if;

  if v_dir then
    if v.statut not in ('en_attente', 'transmise') then raise exception 'deja_traitee'; end if;
    if p_decision = 'transmise' then raise exception 'decision_invalide'; end if;
  else
    if v.statut <> 'en_attente' then raise exception 'deja_traitee'; end if;
  end if;

  perform set_config('app.motif', trim(p_commentaire), true);
  update public.reclamations set
    statut = p_decision,
    decision_par = auth.uid(),
    avis_enseignant = case when v_dir then avis_enseignant else trim(p_commentaire) end,
    commentaire_decision = trim(p_commentaire)
  where id = p_id returning * into v;

  if p_decision = 'acceptee' then
    update public.presences set justifiee = true where id = v.presence_id and statut = 'absent';
  end if;

  select coalesce(c.nom_court, c.nom), s.date into v_cours, v_date
  from public.seances s join public.cours c on c.id = s.cours_id where s.id = v_seance;
  v_titre := case p_decision when 'acceptee' then 'Réclamation acceptée'
                             when 'refusee' then 'Réclamation refusée'
                             else 'Réclamation transmise' end;
  v_msg := case p_decision
    when 'acceptee' then format('%s · %s est maintenant justifiée', v_cours, to_char(v_date, 'DD/MM'))
    when 'refusee' then format('%s · %s : %s', v_cours, to_char(v_date, 'DD/MM'), trim(p_commentaire))
    else 'Le directeur examine votre dossier' end;
  perform public._notifier(v.etudiant_id, v_titre, v_msg, 'reclamation');
  return row_to_json(v);
end $$;

create or replace function public.contester_reclamation(p_id uuid, p_motif text)
returns json language plpgsql security definer set search_path = public as $$
declare
  v public.reclamations;
begin
  select * into v from public.reclamations where id = p_id and etudiant_id = auth.uid() for update;
  if not found then raise exception 'introuvable'; end if;
  if v.statut <> 'refusee' then raise exception 'recours_impossible'; end if;
  if v.decision_par is not null and exists (
       select 1 from public.profils where id = v.decision_par and role = 'directeur') then
    raise exception 'recours_impossible';   -- la décision du directeur est finale
  end if;
  if nullif(trim(p_motif), '') is null then raise exception 'motif_obligatoire'; end if;
  perform set_config('app.motif', 'Recours de l''étudiant : ' || trim(p_motif), true);
  update public.reclamations set statut = 'transmise', commentaire_decision = null
  where id = p_id returning * into v;
  return row_to_json(v);
end $$;

-- ---------------------------------------------------------------------
-- Statistiques (security invoker : la RLS filtre ce que chacun voit)
-- ---------------------------------------------------------------------
create or replace function public.stats_presences(
  p_debut date default null, p_fin date default null,
  p_classe text default null, p_cours_id uuid default null
) returns json language sql stable security invoker set search_path = public as $$
  with base as (
    select p.etudiant_id, p.statut, p.justifiee, s.id as seance_id, s.date,
           c.id as cours_id, coalesce(c.nom_court, c.nom) as cours, c.classe,
           pr.nom
    from public.presences p
    join public.seances s on s.id = p.seance_id
    join public.cours c on c.id = s.cours_id
    left join public.profils pr on pr.id = p.etudiant_id
    where (p_debut is null or s.date >= p_debut)
      and (p_fin is null or s.date <= p_fin)
      and (p_classe is null or c.classe = p_classe)
      and (p_cours_id is null or c.id = p_cours_id)
      and (public.est_directeur() or c.enseignant_id = auth.uid() or p.etudiant_id = auth.uid())
  ),
  par_etudiant as (
    select etudiant_id, nom, classe,
           count(*) filter (where statut = 'present') as presents,
           count(*) filter (where statut = 'retard') as retards,
           count(*) filter (where statut = 'absent') as absences,
           count(*) filter (where statut = 'absent' and not justifiee) as absences_nj,
           count(*) as total
    from base group by etudiant_id, nom, classe
  )
  select json_build_object(
    'total', (select count(*) from base),
    'taux', coalesce((select round(count(*) filter (where statut <> 'absent')::numeric / nullif(count(*), 0), 4) from base), 1),
    'nb_seances', (select count(distinct seance_id) from base),
    'retards', (select count(*) filter (where statut = 'retard') from base),
    'par_classe', coalesce((select json_agg(x order by x.classe) from (
        select classe, round(count(*) filter (where statut <> 'absent')::numeric / count(*), 4) as taux
        from base group by classe) x), '[]'),
    'par_cours', coalesce((select json_agg(x order by x.cours) from (
        select cours_id, cours, classe, count(distinct seance_id) as seances,
               round(count(*) filter (where statut <> 'absent')::numeric / count(*), 4) as taux
        from base group by cours_id, cours, classe) x), '[]'),
    'etudiants', coalesce((select json_agg(e order by e.absences desc, e.nom) from par_etudiant e), '[]')
  )
$$;

-- Étudiants dont les absences non justifiées approchent ou dépassent le seuil.
create or replace function public.etudiants_a_risque()
returns table (etudiant_id uuid, nom text, classe text, cours_id uuid, cours text, absences int, seuil int)
language sql stable security invoker set search_path = public as $$
  select p.etudiant_id, pr.nom, c.classe, c.id, coalesce(c.nom_court, c.nom),
         count(*)::int, (select seuil_exclusion from public.regles where id = 1)
  from public.presences p
  join public.seances s on s.id = p.seance_id
  join public.cours c on c.id = s.cours_id
  join public.profils pr on pr.id = p.etudiant_id
  where p.statut = 'absent' and not p.justifiee
  group by p.etudiant_id, pr.nom, c.classe, c.id, c.nom_court, c.nom
  having count(*) >= (select seuil_exclusion from public.regles where id = 1) - 1
  order by count(*) desc, pr.nom
$$;

-- ---------------------------------------------------------------------
-- Directeur : gestion des comptes
-- ---------------------------------------------------------------------
create or replace function public.gerer_compte(
  p_id uuid, p_role text, p_classe text, p_actif boolean, p_motif text default null
) returns json language plpgsql security definer set search_path = public as $$
declare
  v public.profils;
begin
  if not public.est_directeur() then raise exception 'acces_refuse'; end if;
  if p_role not in ('etudiant', 'enseignant', 'directeur') then raise exception 'role_invalide'; end if;
  if p_id = auth.uid() and (p_role <> 'directeur' or not p_actif) then
    raise exception 'action_interdite';   -- le directeur ne se retire pas ses propres droits
  end if;
  perform set_config('app.motif', coalesce(nullif(trim(p_motif), ''), 'Gestion des comptes'), true);
  update public.profils set role = p_role, actif = p_actif,
    classe = case when p_role = 'etudiant' then nullif(trim(p_classe), '') else null end
  where id = p_id
  returning * into v;
  if not found then raise exception 'introuvable'; end if;
  return json_build_object('id', v.id, 'role', v.role, 'classe', v.classe, 'actif', v.actif);
end $$;

-- Création d'un compte par le directeur (mot de passe provisoire fourni).
create or replace function public.creer_compte(
  p_email text, p_nom text, p_role text, p_classe text, p_mot_de_passe text
) returns uuid language plpgsql security definer set search_path = public, extensions as $$
declare
  v_id uuid := gen_random_uuid();
  v_email text := lower(trim(p_email));
begin
  if not public.est_directeur() then raise exception 'acces_refuse'; end if;
  if p_role not in ('etudiant', 'enseignant', 'directeur') then raise exception 'role_invalide'; end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'email_invalide'; end if;
  if length(coalesce(p_mot_de_passe, '')) < 8 then raise exception 'mot_de_passe_faible'; end if;
  if exists (select 1 from auth.users where email = v_email) then raise exception 'email_existe'; end if;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
    v_email, extensions.crypt(p_mot_de_passe, extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_strip_nulls(jsonb_build_object('nom', trim(p_nom), 'role', p_role,
                                         'classe', nullif(trim(p_classe), ''))),
    now(), now(), '', '', '', ''
  );
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at)
  values (gen_random_uuid(), v_id, v_id::text,
          jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true),
          'email', now(), now());

  perform set_config('app.motif', 'Compte créé par le directeur', true);
  update public.profils set actif = true where id = v_id;
  insert into public.audit_log (acteur_id, action, table_cible, cible_id, details, motif)
  values (auth.uid(), 'compte_cree', 'profils', v_id::text,
          jsonb_build_object('email', v_email, 'role', p_role), 'Compte créé par le directeur');
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- Directeur : planification d'une séance hebdomadaire sur N semaines
-- ---------------------------------------------------------------------
create or replace function public.planifier_seances(
  p_cours_id uuid, p_premiere date, p_heure_debut time, p_heure_fin time,
  p_salle text default null, p_semaines int default 1
) returns int language plpgsql security definer set search_path = public as $$
declare
  v_nb int;
begin
  if not public.est_directeur() then raise exception 'acces_refuse'; end if;
  if p_heure_fin <= p_heure_debut then raise exception 'horaire_invalide'; end if;
  if p_semaines not between 1 and 30 then raise exception 'semaines_invalides'; end if;
  insert into public.seances (cours_id, date, heure_debut, heure_fin, salle)
  select p_cours_id, p_premiere + 7 * k, p_heure_debut, p_heure_fin,
         coalesce(nullif(trim(p_salle), ''), (select salle from public.cours where id = p_cours_id))
  from generate_series(0, p_semaines - 1) k
  where not exists (select 1 from public.seances s where s.cours_id = p_cours_id
                    and s.date = p_premiere + 7 * k and s.heure_debut = p_heure_debut);
  get diagnostics v_nb = row_count;
  return v_nb;
end $$;

-- ---------------------------------------------------------------------
-- Droits d'exécution
-- ---------------------------------------------------------------------
revoke execute on function
  public.corriger_presence(uuid, uuid, text, text),
  public.traiter_auto_declaration(uuid, boolean, text),
  public.traiter_reclamation(uuid, text, text),
  public.contester_reclamation(uuid, text),
  public.stats_presences(date, date, text, uuid),
  public.etudiants_a_risque(),
  public.gerer_compte(uuid, text, text, boolean, text),
  public.creer_compte(text, text, text, text, text),
  public.planifier_seances(uuid, date, time, time, text, int)
from public, anon;
grant execute on function
  public.corriger_presence(uuid, uuid, text, text),
  public.traiter_auto_declaration(uuid, boolean, text),
  public.traiter_reclamation(uuid, text, text),
  public.contester_reclamation(uuid, text),
  public.stats_presences(date, date, text, uuid),
  public.etudiants_a_risque(),
  public.gerer_compte(uuid, text, text, boolean, text),
  public.creer_compte(text, text, text, text, text),
  public.planifier_seances(uuid, date, time, time, text, int)
to authenticated;
