-- =====================================================================
-- ClassCheck — 003 : fonctions de pointage (RPC)
--   Enseignant : ouvrir_seance → generer_qr (toutes les 30 s) → cloturer_seance
--   Étudiant   : scanner_qr (ticket 2 min) → valider_pointage (visage)
-- Les refus renvoient {ok:false, erreur:'code'} et sont tracés dans audit_log.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Outils internes
-- ---------------------------------------------------------------------

-- Distance euclidienne minimale entre un embedding (192) et les N embeddings
-- de référence concaténés (N × 192).
create or replace function public.distance_min_visage(p_sonde float8[], p_refs float8[])
returns float8 language plpgsql immutable as $$
declare
  v_dim constant int := 192;
  v_n int := coalesce(array_length(p_refs, 1), 0) / 192;
  v_min float8 := 'infinity';
  v_somme float8;
begin
  if coalesce(array_length(p_sonde, 1), 0) <> v_dim or v_n = 0 then
    return 'infinity';
  end if;
  for k in 0 .. v_n - 1 loop
    v_somme := 0;
    for i in 1 .. v_dim loop
      v_somme := v_somme + power(p_sonde[i] - p_refs[k * v_dim + i], 2);
    end loop;
    v_min := least(v_min, sqrt(v_somme));
  end loop;
  return v_min;
end $$;

-- Journalise un refus de pointage et renvoie le JSON d'erreur.
create or replace function public._refus_pointage(p_code text, p_seance_id uuid, p_details jsonb default '{}'::jsonb)
returns json language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_log (acteur_id, action, table_cible, cible_id, details)
  values (auth.uid(), 'pointage_refuse', 'seances', p_seance_id::text,
          jsonb_build_object('erreur', p_code) || coalesce(p_details, '{}'::jsonb));
  return json_build_object('ok', false, 'erreur', p_code);
end $$;

-- ---------------------------------------------------------------------
-- Enseignant : ouverture de séance (fenêtre de pointage)
-- ---------------------------------------------------------------------
create or replace function public.ouvrir_seance(
  p_seance_id uuid,
  p_fenetre int default null,
  p_visage boolean default null
) returns json language plpgsql security definer set search_path = public as $$
declare
  v public.seances;
  r public.regles;
begin
  select * into r from public.regles where id = 1;
  select * into v from public.seances where id = p_seance_id for update;
  if not found then raise exception 'seance_introuvable'; end if;
  if not public.est_enseignant_seance(p_seance_id) then raise exception 'acces_refuse'; end if;
  if v.statut = 'cloturee' then raise exception 'seance_cloturee'; end if;
  if v.date <> public.aujourdhui() then raise exception 'seance_pas_aujourdhui'; end if;

  update public.seances set
    statut = 'ouverte',
    -- une séance déjà ouverte garde son heure d'ouverture (la fenêtre ne se rallonge pas)
    ouverte_a = case when v.statut = 'ouverte' then v.ouverte_a else now() end,
    fenetre_minutes = coalesce(p_fenetre, v.fenetre_minutes, r.fenetre_pointage),
    -- si la règle impose le visage, l'enseignant ne peut pas le désactiver
    visage_obligatoire = r.visage_obligatoire or coalesce(p_visage, true)
  where id = p_seance_id
  returning * into v;

  if v.ouverte_a >= now() - interval '2 seconds' then
    insert into public.audit_log (acteur_id, action, table_cible, cible_id, details)
    values (auth.uid(), 'seance_ouverte', 'seances', p_seance_id::text,
            jsonb_build_object('fenetre_minutes', v.fenetre_minutes,
                               'visage_obligatoire', v.visage_obligatoire));
  end if;

  return row_to_json(v);
end $$;

-- ---------------------------------------------------------------------
-- Enseignant : nouveau QR (valable « renouvellement_qr » secondes, 30 par défaut)
-- ---------------------------------------------------------------------
create or replace function public.generer_qr(p_seance_id uuid)
returns json language plpgsql security definer set search_path = public as $$
declare
  v public.seances;
  r public.regles;
  t public.qr_tokens;
begin
  select * into r from public.regles where id = 1;
  select * into v from public.seances where id = p_seance_id;
  if not found then raise exception 'seance_introuvable'; end if;
  if not public.est_enseignant_seance(p_seance_id) then raise exception 'acces_refuse'; end if;
  if v.statut = 'cloturee' then raise exception 'seance_cloturee'; end if;
  if v.statut <> 'ouverte' then raise exception 'seance_non_ouverte'; end if;
  if now() > v.ouverte_a + make_interval(mins => v.fenetre_minutes) then
    raise exception 'hors_fenetre';
  end if;

  -- ménage : anciens codes de cette séance
  delete from public.qr_tokens
  where seance_id = p_seance_id and expire_a < now() - interval '10 minutes';

  insert into public.qr_tokens (seance_id, token, expire_a)
  values (p_seance_id,
          encode(extensions.gen_random_bytes(16), 'hex'),
          now() + make_interval(secs => r.renouvellement_qr))
  returning * into t;

  return json_build_object(
    'seance_id', p_seance_id,
    'token', t.token,
    'expire_a', t.expire_a,
    'duree', r.renouvellement_qr,
    'fin_fenetre', v.ouverte_a + make_interval(mins => v.fenetre_minutes)
  );
end $$;

-- ---------------------------------------------------------------------
-- Étudiant — étape 1 : scan du QR → ticket de 2 minutes
-- ---------------------------------------------------------------------
create or replace function public.scanner_qr(p_seance_id uuid, p_token text)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_s record;
  v_t public.qr_tokens;
  v_ticket public.tickets_pointage;
begin
  if v_uid is null then return json_build_object('ok', false, 'erreur', 'non_connecte'); end if;

  select s.*, c.classe, c.nom as cours_nom into v_s
  from public.seances s join public.cours c on c.id = s.cours_id
  where s.id = p_seance_id;
  if not found then return public._refus_pointage('qr_invalide', null); end if;

  if not exists (
    select 1 from public.profils
    where id = v_uid and role = 'etudiant' and actif and classe = v_s.classe
  ) then
    return public._refus_pointage('non_inscrit', p_seance_id);
  end if;

  if v_s.statut = 'cloturee' then return public._refus_pointage('seance_cloturee', p_seance_id); end if;
  if v_s.statut <> 'ouverte' then return public._refus_pointage('seance_non_ouverte', p_seance_id); end if;
  if now() > v_s.ouverte_a + make_interval(mins => v_s.fenetre_minutes) then
    return public._refus_pointage('hors_fenetre', p_seance_id);
  end if;
  if exists (select 1 from public.presences where seance_id = p_seance_id and etudiant_id = v_uid) then
    return public._refus_pointage('deja_pointe', p_seance_id);
  end if;

  select * into v_t from public.qr_tokens where seance_id = p_seance_id and token = p_token;
  if not found then return public._refus_pointage('qr_invalide', p_seance_id); end if;
  if v_t.expire_a < now() then
    return public._refus_pointage('qr_expire', p_seance_id,
      jsonb_build_object('expire_depuis_s', extract(epoch from now() - v_t.expire_a)::int));
  end if;

  insert into public.tickets_pointage (seance_id, etudiant_id, qr_token_id, expire_a)
  values (p_seance_id, v_uid, v_t.id, now() + interval '2 minutes')
  returning * into v_ticket;

  return json_build_object(
    'ok', true,
    'ticket_id', v_ticket.id,
    'expire_a', v_ticket.expire_a,
    'visage_obligatoire', v_s.visage_obligatoire,
    'cours_nom', v_s.cours_nom,
    'salle', coalesce(v_s.salle, '')
  );
end $$;

-- ---------------------------------------------------------------------
-- Étudiant — étape 2 : validation (visage + vivacité) → présence
-- p_embedding : 192 valeurs calculées sur le selfie (la photo n'est pas envoyée)
-- ---------------------------------------------------------------------
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
    -- 3 essais maximum par ticket (anti force brute)
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
    if v_dist > v_r.seuil_visage then
      return public._refus_pointage('visage_non_reconnu', v_ticket.seance_id,
        jsonb_build_object('distance', round(v_dist::numeric, 3), 'seuil', v_r.seuil_visage));
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
                             'distance', case when v_dist is null then null else round(v_dist::numeric, 3) end));

  return json_build_object(
    'ok', true,
    'statut', v_presence.statut,
    'pointe_a', v_presence.pointe_a,
    'distance', v_dist,
    'cours_nom', v_s.cours_nom,
    'salle', coalesce(v_s.salle, '')
  );
end $$;

-- ---------------------------------------------------------------------
-- Enseignant : clôture → les non-pointés passent en absent
-- ---------------------------------------------------------------------
create or replace function public.cloturer_seance(p_seance_id uuid)
returns json language plpgsql security definer set search_path = public as $$
declare
  v public.seances;
  v_classe text;
  v_nb_auto int;
  v_noms text[];
  v_presents int;
  v_absents int;
begin
  select * into v from public.seances where id = p_seance_id for update;
  if not found then raise exception 'seance_introuvable'; end if;
  if not (public.est_enseignant_seance(p_seance_id) or public.est_directeur()) then
    raise exception 'acces_refuse';
  end if;
  if v.statut = 'cloturee' then raise exception 'seance_cloturee'; end if;

  select c.classe into v_classe from public.cours c where c.id = v.cours_id;

  with ins as (
    insert into public.presences (seance_id, etudiant_id, statut, methode, valide_par)
    select p_seance_id, p.id, 'absent', 'auto_cloture', auth.uid()
    from public.profils p
    where p.role = 'etudiant' and p.actif and p.classe = v_classe
      and not exists (
        select 1 from public.presences x where x.seance_id = p_seance_id and x.etudiant_id = p.id
      )
    returning etudiant_id
  )
  select count(*), coalesce(array_agg(pr.nom order by pr.nom), '{}')
  into v_nb_auto, v_noms
  from ins join public.profils pr on pr.id = ins.etudiant_id;

  update public.seances set statut = 'cloturee', cloturee_a = now() where id = p_seance_id;
  -- plus aucun pointage possible : codes et tickets invalidés
  delete from public.qr_tokens where seance_id = p_seance_id;
  update public.tickets_pointage set expire_a = now()
  where seance_id = p_seance_id and utilise_a is null and expire_a > now();

  select count(*) filter (where statut in ('present', 'retard')),
         count(*) filter (where statut = 'absent')
  into v_presents, v_absents
  from public.presences where seance_id = p_seance_id;

  insert into public.audit_log (acteur_id, action, table_cible, cible_id, details)
  values (auth.uid(), 'seance_cloturee', 'seances', p_seance_id::text,
          jsonb_build_object('presents', v_presents, 'absents', v_absents,
                             'absents_automatiques', v_nb_auto, 'noms', to_jsonb(v_noms)));

  return json_build_object(
    'presents', v_presents,
    'absents', v_absents,
    'absents_automatiques', v_nb_auto,
    'noms', to_jsonb(v_noms)
  );
end $$;

-- ---------------------------------------------------------------------
-- Compteur « 24 présents sur 30 » (agrégat, sans exposer les autres étudiants)
-- ---------------------------------------------------------------------
create or replace function public.compteur_seance(p_seance_id uuid)
returns json language plpgsql stable security definer set search_path = public as $$
declare
  v_classe text;
  v_total int;
  v_presents int;
begin
  if not (public.est_etudiant_seance(p_seance_id)
          or public.est_enseignant_seance(p_seance_id)
          or public.est_directeur()) then
    raise exception 'acces_refuse';
  end if;
  select c.classe into v_classe
  from public.seances s join public.cours c on c.id = s.cours_id where s.id = p_seance_id;
  select count(*) into v_total from public.profils
  where role = 'etudiant' and actif and classe = v_classe;
  select count(*) into v_presents from public.presences
  where seance_id = p_seance_id and statut in ('present', 'retard');
  return json_build_object('presents', v_presents, 'total', v_total);
end $$;

-- ---------------------------------------------------------------------
-- Enregistrement du visage : 5 embeddings × 192 = 960 valeurs
-- ---------------------------------------------------------------------
create or replace function public.enregistrer_visage(p_embeddings float8[])
returns int language plpgsql security definer set search_path = public as $$
declare
  v_existait boolean;
begin
  if auth.uid() is null then raise exception 'non_connecte'; end if;
  if coalesce(array_length(p_embeddings, 1), 0) <> 960 then
    raise exception 'nb_captures_invalide';
  end if;
  select face_embedding is not null into v_existait from public.profils where id = auth.uid();
  update public.profils set face_embedding = p_embeddings, nb_captures = 5 where id = auth.uid();
  insert into public.audit_log (acteur_id, action, table_cible, cible_id, details)
  values (auth.uid(), case when v_existait then 'visage_reenregistre' else 'visage_enregistre' end,
          'profils', auth.uid()::text, jsonb_build_object('captures', 5));
  return 5;
end $$;

-- ---------------------------------------------------------------------
-- Droits d'exécution
-- ---------------------------------------------------------------------
revoke execute on function public._refus_pointage(text, uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.distance_min_visage(float8[], float8[]) from public, anon;

revoke execute on function
  public.ouvrir_seance(uuid, int, boolean),
  public.generer_qr(uuid),
  public.scanner_qr(uuid, text),
  public.valider_pointage(uuid, text, float8[], boolean),
  public.cloturer_seance(uuid),
  public.compteur_seance(uuid),
  public.enregistrer_visage(float8[])
from public, anon;

grant execute on function
  public.distance_min_visage(float8[], float8[]),
  public.ouvrir_seance(uuid, int, boolean),
  public.generer_qr(uuid),
  public.scanner_qr(uuid, text),
  public.valider_pointage(uuid, text, float8[], boolean),
  public.cloturer_seance(uuid),
  public.compteur_seance(uuid),
  public.enregistrer_visage(float8[])
to authenticated;
