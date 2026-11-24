-- =====================================================================
-- ClassCheck — 002 : sécurité (RLS + droits par colonne)
-- Principe : étudiant → ses données ; enseignant → ses cours ; directeur → tout.
-- Les écritures sensibles (présences, QR, tickets) passent UNIQUEMENT
-- par les fonctions SQL de 003 (security definer).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Fonctions d'aide (security definer : pas de récursion RLS)
-- ---------------------------------------------------------------------
create or replace function public.mon_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.profils where id = auth.uid() and actif
$$;

create or replace function public.ma_classe()
returns text language sql stable security definer set search_path = public as $$
  select classe from public.profils where id = auth.uid() and role = 'etudiant' and actif
$$;

create or replace function public.est_directeur()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profils
    where id = auth.uid() and role = 'directeur' and actif
  )
$$;

create or replace function public.est_enseignant_seance(p_seance_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.seances s
    join public.cours c on c.id = s.cours_id
    join public.profils p on p.id = c.enseignant_id
    where s.id = p_seance_id and c.enseignant_id = auth.uid() and p.actif
  )
$$;

create or replace function public.est_etudiant_seance(p_seance_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.seances s
    join public.cours c on c.id = s.cours_id
    where s.id = p_seance_id and c.classe = public.ma_classe()
  )
$$;

-- Un enseignant voit les étudiants des classes où il enseigne.
create or replace function public.enseigne_a_la_classe(p_classe text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.cours c
    where c.enseignant_id = auth.uid() and c.classe = p_classe
  )
$$;

revoke execute on function public.mon_role(), public.ma_classe(), public.est_directeur(),
  public.est_enseignant_seance(uuid), public.est_etudiant_seance(uuid),
  public.enseigne_a_la_classe(text) from public, anon;
grant execute on function public.mon_role(), public.ma_classe(), public.est_directeur(),
  public.est_enseignant_seance(uuid), public.est_etudiant_seance(uuid),
  public.enseigne_a_la_classe(text) to authenticated;

-- ---------------------------------------------------------------------
-- Activation de la RLS sur toutes les tables
-- ---------------------------------------------------------------------
alter table public.profils            enable row level security;
alter table public.cours              enable row level security;
alter table public.seances            enable row level security;
alter table public.presences          enable row level security;
alter table public.qr_tokens          enable row level security;
alter table public.tickets_pointage   enable row level security;
alter table public.auto_declarations  enable row level security;
alter table public.reclamations       enable row level security;
alter table public.notifications      enable row level security;
alter table public.regles             enable row level security;
alter table public.audit_log          enable row level security;

-- ---------------------------------------------------------------------
-- Droits de base : rien pour anon ; écritures limitées pour authenticated
-- ---------------------------------------------------------------------
revoke all on all tables in schema public from anon;

-- profils : la colonne face_embedding n'est lisible/modifiable par PERSONNE
-- via l'API (ni même son propriétaire) ; seules les fonctions SQL y accèdent.
revoke all on public.profils from authenticated;
grant select (id, nom, email, role, classe, nb_captures, actif, created_at)
  on public.profils to authenticated;
grant update (nom, classe) on public.profils to authenticated;

-- Tables écrites uniquement par les fonctions SQL
revoke insert, update, delete on public.presences, public.qr_tokens,
  public.tickets_pointage, public.audit_log from authenticated;
grant select on public.presences, public.qr_tokens, public.tickets_pointage,
  public.audit_log to authenticated;

-- Notifications : l'utilisateur ne peut que marquer comme lu
revoke insert, update, delete on public.notifications from authenticated;
grant select on public.notifications to authenticated;
grant update (lu) on public.notifications to authenticated;

-- Réclamations / auto-déclarations : création par l'étudiant, traitement par RPC (Sprint 2)
revoke update, delete on public.reclamations, public.auto_declarations from authenticated;
grant select, insert on public.reclamations, public.auto_declarations to authenticated;

-- ---------------------------------------------------------------------
-- Politiques
-- ---------------------------------------------------------------------

-- profils
drop policy if exists profils_select on public.profils;
create policy profils_select on public.profils for select to authenticated using (
  id = auth.uid()
  or public.est_directeur()
  or role in ('enseignant', 'directeur')                       -- noms des enseignants
  or (role = 'etudiant' and public.enseigne_a_la_classe(classe))
);

drop policy if exists profils_update_soi on public.profils;
create policy profils_update_soi on public.profils for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- cours
drop policy if exists cours_select on public.cours;
create policy cours_select on public.cours for select to authenticated using (
  public.est_directeur() or enseignant_id = auth.uid() or classe = public.ma_classe()
);
drop policy if exists cours_directeur on public.cours;
create policy cours_directeur on public.cours for all to authenticated
  using (public.est_directeur()) with check (public.est_directeur());

-- seances
drop policy if exists seances_select on public.seances;
create policy seances_select on public.seances for select to authenticated using (
  public.est_directeur()
  or exists (
    select 1 from public.cours c
    where c.id = cours_id
      and (c.enseignant_id = auth.uid() or c.classe = public.ma_classe())
  )
);
drop policy if exists seances_directeur on public.seances;
create policy seances_directeur on public.seances for all to authenticated
  using (public.est_directeur()) with check (public.est_directeur());

-- presences
drop policy if exists presences_select on public.presences;
create policy presences_select on public.presences for select to authenticated using (
  etudiant_id = auth.uid()
  or public.est_enseignant_seance(seance_id)
  or public.est_directeur()
);

-- qr_tokens : jamais visibles par les étudiants
drop policy if exists qr_tokens_select on public.qr_tokens;
create policy qr_tokens_select on public.qr_tokens for select to authenticated using (
  public.est_enseignant_seance(seance_id) or public.est_directeur()
);

-- tickets_pointage
drop policy if exists tickets_select on public.tickets_pointage;
create policy tickets_select on public.tickets_pointage for select to authenticated using (
  etudiant_id = auth.uid() or public.est_directeur()
);

-- auto_declarations
drop policy if exists autodecl_select on public.auto_declarations;
create policy autodecl_select on public.auto_declarations for select to authenticated using (
  etudiant_id = auth.uid()
  or public.est_enseignant_seance(seance_id)
  or public.est_directeur()
);
drop policy if exists autodecl_insert on public.auto_declarations;
create policy autodecl_insert on public.auto_declarations for insert to authenticated with check (
  etudiant_id = auth.uid()
  and statut = 'en_attente'
  and public.est_etudiant_seance(seance_id)
);

-- reclamations
drop policy if exists reclamations_select on public.reclamations;
create policy reclamations_select on public.reclamations for select to authenticated using (
  etudiant_id = auth.uid()
  or public.est_directeur()
  or exists (
    select 1 from public.presences p
    where p.id = presence_id and public.est_enseignant_seance(p.seance_id)
  )
);
drop policy if exists reclamations_insert on public.reclamations;
create policy reclamations_insert on public.reclamations for insert to authenticated with check (
  etudiant_id = auth.uid()
  and statut = 'en_attente'
  and exists (select 1 from public.presences p where p.id = presence_id and p.etudiant_id = auth.uid())
);

-- notifications
drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications for select to authenticated
  using (destinataire_id = auth.uid());
drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications for update to authenticated
  using (destinataire_id = auth.uid()) with check (destinataire_id = auth.uid());

-- regles : lecture pour tous les connectés, modification par le directeur
drop policy if exists regles_select on public.regles;
create policy regles_select on public.regles for select to authenticated using (true);
drop policy if exists regles_update on public.regles;
create policy regles_update on public.regles for update to authenticated
  using (public.est_directeur()) with check (public.est_directeur());

-- audit_log : lecture directeur uniquement
drop policy if exists audit_select on public.audit_log;
create policy audit_select on public.audit_log for select to authenticated
  using (public.est_directeur());

-- ---------------------------------------------------------------------
-- Realtime : présences en direct (la RLS s'applique aussi au temps réel)
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'presences'
  ) then
    alter publication supabase_realtime add table public.presences;
  end if;
end $$;
