-- =====================================================================
-- ClassCheck — 006 : corrections de la base (droits, sécurité, visage)
--
-- Problèmes constatés sur la base Supabase :
--  1. `authenticated` n'avait AUCUN droit SELECT sur cours / seances / regles
--     → les écrans d'accueil et l'emploi du temps ne pouvaient rien charger.
--  2. `authenticated` avait TRUNCATE sur toutes les tables (TRUNCATE ignore la RLS).
--  3. Un étudiant pouvait modifier sa propre `classe` et lire les données
--     d'une autre classe.
--  4. Fonctions de trigger exécutables via l'API (/rest/v1/rpc/...).
--  5. search_path non fixé sur 3 fonctions (alerte du linter Supabase).
--  6. Reconnaissance faciale plus stricte : vote sur les 5 captures,
--     contrôle de cohérence à l'enregistrement, refus d'un visage déjà
--     enregistré sur un autre compte.
-- Réexécutable.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Table presences incomplète sur la base en ligne (créée avec une
--    ancienne version du script) : colonnes et contraintes manquantes.
--    Sans elles, valider_pointage échouait et le double pointage n'était
--    pas bloqué par la base.
-- ---------------------------------------------------------------------
alter table public.presences
  add column if not exists valide_par uuid references public.profils(id) on delete set null,
  add column if not exists pointe_a timestamptz,
  add column if not exists distance float8,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'presences_seance_id_etudiant_id_key') then
    alter table public.presences add constraint presences_seance_id_etudiant_id_key unique (seance_id, etudiant_id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'presences_methode_check') then
    alter table public.presences add constraint presences_methode_check
      check (methode in ('qr_visage', 'qr', 'manuel', 'auto_cloture', 'auto_declaration'));
  end if;
end $$;
update public.presences p set pointe_a = ((s.date + s.heure_debut) at time zone 'Africa/Tunis')
  + make_interval(mins => case p.statut when 'retard' then 18 else 3 end)
from public.seances s where s.id = p.seance_id and p.statut <> 'absent' and p.pointe_a is null;

-- ---------------------------------------------------------------------
-- 1–2. Droits de table
-- ---------------------------------------------------------------------
revoke truncate, references, trigger on all tables in schema public from authenticated, anon;

grant select, insert, update, delete on public.cours, public.seances to authenticated;  -- RLS : directeur seul en écriture
grant select, update on public.regles to authenticated;                                -- RLS : directeur seul en écriture

-- ---------------------------------------------------------------------
-- 3. Profils : l'utilisateur ne modifie que son nom (la classe est gérée
--    par le directeur, sinon un étudiant changerait de classe à volonté).
-- ---------------------------------------------------------------------
revoke update on public.profils from authenticated;
grant update (nom) on public.profils to authenticated;

-- ---------------------------------------------------------------------
-- 4–5. Fonctions internes
-- ---------------------------------------------------------------------
alter function public.aujourdhui() set search_path = public;
alter function public._motif_courant() set search_path = public;
alter function public.distance_min_visage(float8[], float8[]) set search_path = public;

revoke execute on function
  public.handle_new_user(),
  public.trg_audit_presences(),
  public.trg_audit_reclamations(),
  public.trg_audit_auto_declarations(),
  public.trg_audit_regles(),
  public.trg_audit_profils()
from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 6. Visage : règles plus précises
-- ---------------------------------------------------------------------
alter table public.regles
  add column if not exists votes_visage int not null default 2
    check (votes_visage between 1 and 5);
comment on column public.regles.votes_visage is
  'Nombre minimal de captures de référence (sur 5) qui doivent être sous le seuil pour accepter un visage.';

-- Nombre de références (blocs de 192) à une distance <= p_seuil de la sonde.
create or replace function public.votes_visage(p_sonde float8[], p_refs float8[], p_seuil float8)
returns int language plpgsql immutable set search_path = public as $$
declare
  v_dim constant int := 192;
  v_n int := coalesce(array_length(p_refs, 1), 0) / 192;
  v_votes int := 0;
  v_somme float8;
begin
  if coalesce(array_length(p_sonde, 1), 0) <> v_dim then return 0; end if;
  for k in 0 .. v_n - 1 loop
    v_somme := 0;
    for i in 1 .. v_dim loop
      v_somme := v_somme + power(p_sonde[i] - p_refs[k * v_dim + i], 2);
    end loop;
    if sqrt(v_somme) <= p_seuil then v_votes := v_votes + 1; end if;
  end loop;
  return v_votes;
end $$;

-- Plus grande distance entre deux captures d'un même enregistrement.
create or replace function public.dispersion_visage(p_refs float8[])
returns float8 language plpgsql immutable set search_path = public as $$
declare
  v_dim constant int := 192;
  v_n int := coalesce(array_length(p_refs, 1), 0) / 192;
  v_max float8 := 0;
  v_somme float8;
begin
  for a in 0 .. v_n - 2 loop
    for b in a + 1 .. v_n - 1 loop
      v_somme := 0;
      for i in 1 .. v_dim loop
        v_somme := v_somme + power(p_refs[a * v_dim + i] - p_refs[b * v_dim + i], 2);
      end loop;
      v_max := greatest(v_max, sqrt(v_somme));
    end loop;
  end loop;
  return v_max;
end $$;

revoke execute on function public.votes_visage(float8[], float8[], float8),
  public.dispersion_visage(float8[]) from public, anon;
grant execute on function public.votes_visage(float8[], float8[], float8),
  public.dispersion_visage(float8[]) to authenticated;

-- Enregistrement : 5 captures cohérentes et visage non déjà utilisé ailleurs.
create or replace function public.enregistrer_visage(p_embeddings float8[])
returns int language plpgsql security definer set search_path = public as $$
declare
  v_existait boolean;
  v_r public.regles;
  v_autre uuid;
begin
  if auth.uid() is null then raise exception 'non_connecte'; end if;
  if coalesce(array_length(p_embeddings, 1), 0) <> 960 then
    raise exception 'nb_captures_invalide';
  end if;
  select * into v_r from public.regles where id = 1;

  -- Les 5 captures doivent montrer la même personne.
  if public.dispersion_visage(p_embeddings) > v_r.seuil_visage * 1.3 then
    raise exception 'captures_incoherentes';
  end if;

  -- Un même visage ne peut pas servir à deux comptes (prête-nom).
  select p.id into v_autre
  from public.profils p
  where p.id <> auth.uid() and p.face_embedding is not null
    and public.votes_visage(p_embeddings[1:192], p.face_embedding, v_r.seuil_visage * 0.8) >= 2
  limit 1;
  if v_autre is not null then
    insert into public.audit_log (acteur_id, action, table_cible, cible_id, details)
    values (auth.uid(), 'visage_refuse', 'profils', auth.uid()::text,
            jsonb_build_object('raison', 'visage_deja_utilise'));
    raise exception 'visage_deja_utilise';
  end if;

  select face_embedding is not null into v_existait from public.profils where id = auth.uid();
  update public.profils set face_embedding = p_embeddings, nb_captures = 5 where id = auth.uid();
  insert into public.audit_log (acteur_id, action, table_cible, cible_id, details)
  values (auth.uid(), case when v_existait then 'visage_reenregistre' else 'visage_enregistre' end,
          'profils', auth.uid()::text,
          jsonb_build_object('captures', 5,
                             'dispersion', round(public.dispersion_visage(p_embeddings)::numeric, 3)));
  return 5;
end $$;

-- Validation : distance minimale <= seuil ET au moins `votes_visage` captures d'accord.
create or replace function public.valider_pointage(
  p_ticket_id uuid,
  p_methode text default 'qr_visage',
  p_embedding float8[] default null,
  p_vivacite boolean default false
) returns json language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_ticket public.tickets_pointage;
  v_s record;
  v_r public.regles;
  v_refs float8[];
  v_dist float8;
  v_votes int;
  v_presence public.presences;
begin
  select * into v_r from public.regles where id = 1;

  select * into v_ticket from public.tickets_pointage
  where id = p_ticket_id and etudiant_id = v_uid
  for update;
  if not found then return public._refus_pointage('ticket_invalide', null); end if;

  if v_ticket.utilise_a is not null then
    return public._refus_pointage('ticket_deja_utilise', v_ticket.seance_id);
  end if;
  if v_ticket.expire_a < now() then
    return public._refus_pointage('ticket_expire', v_ticket.seance_id);
  end if;

  select s.*, c.nom as cours_nom into v_s
  from public.seances s join public.cours c on c.id = s.cours_id
  where s.id = v_ticket.seance_id;
  if v_s.statut = 'cloturee' then return public._refus_pointage('seance_cloturee', v_ticket.seance_id); end if;

  if exists (select 1 from public.presences where seance_id = v_ticket.seance_id and etudiant_id = v_uid) then
    return public._refus_pointage('deja_pointe', v_ticket.seance_id);
  end if;

  if p_methode not in ('qr_visage', 'qr') then
    return public._refus_pointage('methode_invalide', v_ticket.seance_id);
  end if;
  if v_s.visage_obligatoire and p_methode <> 'qr_visage' then
    return public._refus_pointage('visage_requis', v_ticket.seance_id);
  end if;

  if p_methode = 'qr_visage' then
    update public.tickets_pointage set tentatives = tentatives + 1
    where id = p_ticket_id returning * into v_ticket;
    if v_ticket.tentatives > 3 then
      return public._refus_pointage('trop_de_tentatives', v_ticket.seance_id);
    end if;

    if not coalesce(p_vivacite, false) then
      return public._refus_pointage('vivacite_echouee', v_ticket.seance_id);
    end if;
    if coalesce(array_length(p_embedding, 1), 0) <> 192 then
      return public._refus_pointage('embedding_invalide', v_ticket.seance_id);
    end if;

    select face_embedding into v_refs from public.profils where id = v_uid;
    if v_refs is null then
      return public._refus_pointage('visage_non_enregistre', v_ticket.seance_id);
    end if;

    v_dist := public.distance_min_visage(p_embedding, v_refs);
    v_votes := public.votes_visage(p_embedding, v_refs, v_r.seuil_visage);
    if v_dist > v_r.seuil_visage or v_votes < least(v_r.votes_visage, array_length(v_refs, 1) / 192) then
      return public._refus_pointage('visage_non_reconnu', v_ticket.seance_id,
        jsonb_build_object('distance', round(v_dist::numeric, 3), 'seuil', v_r.seuil_visage,
                           'votes', v_votes, 'votes_requis', v_r.votes_visage));
    end if;
  end if;

  begin
    insert into public.presences (seance_id, etudiant_id, statut, methode, pointe_a, distance)
    values (v_ticket.seance_id, v_uid, 'present', p_methode, now(), v_dist)
    returning * into v_presence;
  exception when unique_violation then
    return public._refus_pointage('deja_pointe', v_ticket.seance_id);
  end;

  update public.tickets_pointage set utilise_a = now() where id = p_ticket_id;

  insert into public.audit_log (acteur_id, action, table_cible, cible_id, details)
  values (v_uid, 'pointage_valide', 'presences', v_presence.id::text,
          jsonb_build_object('seance_id', v_ticket.seance_id, 'methode', p_methode,
                             'distance', case when v_dist is null then null else round(v_dist::numeric, 3) end,
                             'votes', v_votes));

  return json_build_object(
    'ok', true,
    'statut', v_presence.statut,
    'pointe_a', v_presence.pointe_a,
    'distance', v_dist,
    'cours_nom', v_s.cours_nom,
    'salle', coalesce(v_s.salle, '')
  );
end $$;

revoke execute on function public.enregistrer_visage(float8[]),
  public.valider_pointage(uuid, text, float8[], boolean) from public, anon;
grant execute on function public.enregistrer_visage(float8[]),
  public.valider_pointage(uuid, text, float8[], boolean) to authenticated;
