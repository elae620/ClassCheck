-- =====================================================================
-- ClassCheck — 004 : triggers du journal d'audit
-- Toute correction manuelle ou décision écrit une ligne dans audit_log,
-- avec un motif OBLIGATOIRE.
--
-- Convention : une fonction (RPC) qui modifie une présence, une
-- réclamation ou une auto-déclaration fournit le motif via
--     perform set_config('app.motif', 'texte du motif', true);
-- avant son UPDATE. Sans motif, le trigger refuse la modification.
-- =====================================================================

create or replace function public._motif_courant()
returns text language sql stable as $$
  select nullif(trim(current_setting('app.motif', true)), '')
$$;

-- ---------------------------------------------------------------------
-- Présences : correction de statut
-- ---------------------------------------------------------------------
create or replace function public.trg_audit_presences()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_motif text := public._motif_courant();
begin
  if new.statut is distinct from old.statut then
    if v_motif is null then
      raise exception 'motif_obligatoire';
    end if;
    new.updated_at := now();
    insert into public.audit_log (acteur_id, action, table_cible, cible_id, details, motif)
    values (auth.uid(), 'correction_presence', 'presences', new.id::text,
            jsonb_build_object('seance_id', new.seance_id, 'etudiant_id', new.etudiant_id,
                               'ancien', old.statut, 'nouveau', new.statut,
                               'methode', new.methode),
            v_motif);
  end if;
  return new;
end $$;

drop trigger if exists audit_presences on public.presences;
create trigger audit_presences
  before update on public.presences
  for each row execute function public.trg_audit_presences();

-- ---------------------------------------------------------------------
-- Réclamations : décision (enseignant ou directeur)
-- ---------------------------------------------------------------------
create or replace function public.trg_audit_reclamations()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_motif text := coalesce(nullif(trim(new.commentaire_decision), ''), public._motif_courant());
begin
  if new.statut is distinct from old.statut then
    if v_motif is null then
      raise exception 'motif_obligatoire';
    end if;
    new.traite_a := now();
    insert into public.audit_log (acteur_id, action, table_cible, cible_id, details, motif)
    values (auth.uid(), 'decision_reclamation', 'reclamations', new.id::text,
            jsonb_build_object('etudiant_id', new.etudiant_id, 'presence_id', new.presence_id,
                               'ancien', old.statut, 'nouveau', new.statut),
            v_motif);
  end if;
  return new;
end $$;

drop trigger if exists audit_reclamations on public.reclamations;
create trigger audit_reclamations
  before update on public.reclamations
  for each row execute function public.trg_audit_reclamations();

-- ---------------------------------------------------------------------
-- Auto-déclarations : validation / refus
-- ---------------------------------------------------------------------
create or replace function public.trg_audit_auto_declarations()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_motif text := public._motif_courant();
begin
  if new.statut is distinct from old.statut then
    if v_motif is null then
      raise exception 'motif_obligatoire';
    end if;
    new.traite_a := now();
    insert into public.audit_log (acteur_id, action, table_cible, cible_id, details, motif)
    values (auth.uid(), 'decision_auto_declaration', 'auto_declarations', new.id::text,
            jsonb_build_object('etudiant_id', new.etudiant_id, 'seance_id', new.seance_id,
                               'type', new.type, 'ancien', old.statut, 'nouveau', new.statut),
            v_motif);
  end if;
  return new;
end $$;

drop trigger if exists audit_auto_declarations on public.auto_declarations;
create trigger audit_auto_declarations
  before update on public.auto_declarations
  for each row execute function public.trg_audit_auto_declarations();

-- ---------------------------------------------------------------------
-- Règles de l'établissement
-- ---------------------------------------------------------------------
create or replace function public.trg_audit_regles()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.updated_at := now();
  insert into public.audit_log (acteur_id, action, table_cible, cible_id, details, motif)
  values (auth.uid(), 'regles_modifiees', 'regles', '1',
          jsonb_build_object('avant', to_jsonb(old) - 'updated_at', 'apres', to_jsonb(new) - 'updated_at'),
          public._motif_courant());
  return new;
end $$;

drop trigger if exists audit_regles on public.regles;
create trigger audit_regles
  before update on public.regles
  for each row execute function public.trg_audit_regles();

-- ---------------------------------------------------------------------
-- Comptes : changement de rôle ou activation
-- ---------------------------------------------------------------------
create or replace function public.trg_audit_profils()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role or new.actif is distinct from old.actif then
    insert into public.audit_log (acteur_id, action, table_cible, cible_id, details, motif)
    values (auth.uid(), 'compte_modifie', 'profils', new.id::text,
            jsonb_build_object('role', jsonb_build_array(old.role, new.role),
                               'actif', jsonb_build_array(old.actif, new.actif)),
            public._motif_courant());
  end if;
  return new;
end $$;

drop trigger if exists audit_profils on public.profils;
create trigger audit_profils
  after update on public.profils
  for each row execute function public.trg_audit_profils();

revoke execute on function public._motif_courant() from public, anon;
