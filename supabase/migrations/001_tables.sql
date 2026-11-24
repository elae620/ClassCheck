-- =====================================================================
-- ClassCheck — 001 : tables
-- À exécuter dans l'ordre (001 → 005) dans le SQL Editor de Supabase.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- Date du jour à l'heure de Tunis (évite les décalages UTC autour de minuit).
create or replace function public.aujourdhui()
returns date language sql stable as $$
  select (now() at time zone 'Africa/Tunis')::date
$$;

-- ---------------------------------------------------------------------
-- Profils (1 ligne par compte auth.users)
-- ---------------------------------------------------------------------
create table if not exists public.profils (
  id              uuid primary key references auth.users(id) on delete cascade,
  nom             text not null,
  email           text,
  role            text not null default 'etudiant'
                  check (role in ('etudiant', 'enseignant', 'directeur')),
  classe          text,
  -- 5 embeddings de 192 valeurs concaténés (960 nombres). Jamais de photo.
  face_embedding  float8[],
  nb_captures     int not null default 0,
  actif           boolean not null default true,
  created_at      timestamptz not null default now(),
  constraint face_embedding_taille
    check (face_embedding is null or array_length(face_embedding, 1) = 960)
);

-- ---------------------------------------------------------------------
-- Cours et séances
-- ---------------------------------------------------------------------
create table if not exists public.cours (
  id             uuid primary key default gen_random_uuid(),
  code           text unique,
  nom            text not null,
  nom_court      text,
  classe         text not null,
  salle          text,
  enseignant_id  uuid references public.profils(id) on delete set null,
  created_at     timestamptz not null default now()
);

create table if not exists public.seances (
  id                  uuid primary key default gen_random_uuid(),
  cours_id            uuid not null references public.cours(id) on delete cascade,
  date                date not null,
  heure_debut         time not null,
  heure_fin           time not null,
  salle               text,
  statut              text not null default 'planifiee'
                      check (statut in ('planifiee', 'ouverte', 'cloturee')),
  ouverte_a           timestamptz,
  fenetre_minutes     int check (fenetre_minutes between 1 and 120),
  visage_obligatoire  boolean not null default true,
  cloturee_a          timestamptz,
  created_at          timestamptz not null default now(),
  check (heure_fin > heure_debut)
);

-- ---------------------------------------------------------------------
-- Présences
-- ---------------------------------------------------------------------
create table if not exists public.presences (
  id           uuid primary key default gen_random_uuid(),
  seance_id    uuid not null references public.seances(id) on delete cascade,
  etudiant_id  uuid not null references public.profils(id) on delete cascade,
  statut       text not null check (statut in ('present', 'absent', 'retard')),
  methode      text not null
               check (methode in ('qr_visage', 'qr', 'manuel', 'auto_cloture', 'auto_declaration')),
  valide_par   uuid references public.profils(id) on delete set null,
  pointe_a     timestamptz,
  distance     float8,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (seance_id, etudiant_id)   -- empêche tout double pointage
);

-- ---------------------------------------------------------------------
-- Pointage en 2 étapes : QR (30 s) → ticket (2 min, usage unique)
-- ---------------------------------------------------------------------
create table if not exists public.qr_tokens (
  id         uuid primary key default gen_random_uuid(),
  seance_id  uuid not null references public.seances(id) on delete cascade,
  token      text not null unique,
  cree_a     timestamptz not null default now(),
  expire_a   timestamptz not null
);

create table if not exists public.tickets_pointage (
  id           uuid primary key default gen_random_uuid(),
  seance_id    uuid not null references public.seances(id) on delete cascade,
  etudiant_id  uuid not null references public.profils(id) on delete cascade,
  qr_token_id  uuid references public.qr_tokens(id) on delete set null,
  cree_a       timestamptz not null default now(),
  expire_a     timestamptz not null,
  utilise_a    timestamptz,
  tentatives   int not null default 0
);

-- ---------------------------------------------------------------------
-- Auto-déclarations, réclamations, notifications (Sprint 2)
-- ---------------------------------------------------------------------
create table if not exists public.auto_declarations (
  id           uuid primary key default gen_random_uuid(),
  seance_id    uuid not null references public.seances(id) on delete cascade,
  etudiant_id  uuid not null references public.profils(id) on delete cascade,
  type         text not null check (type in ('retard', 'absence_justifiee')),
  motif        text not null check (length(trim(motif)) > 0),
  statut       text not null default 'en_attente'
               check (statut in ('en_attente', 'validee', 'refusee')),
  traite_par   uuid references public.profils(id) on delete set null,
  traite_a     timestamptz,
  created_at   timestamptz not null default now(),
  unique (seance_id, etudiant_id)
);

create table if not exists public.reclamations (
  id                    uuid primary key default gen_random_uuid(),
  presence_id           uuid not null references public.presences(id) on delete cascade,
  etudiant_id           uuid not null references public.profils(id) on delete cascade,
  motif                 text not null check (length(trim(motif)) > 0),
  justificatif_url      text,
  statut                text not null default 'en_attente'
                        check (statut in ('en_attente', 'acceptee', 'refusee', 'transmise')),
  avis_enseignant       text,
  decision_par          uuid references public.profils(id) on delete set null,
  commentaire_decision  text,
  traite_a              timestamptz,
  created_at            timestamptz not null default now()
);

create table if not exists public.notifications (
  id               uuid primary key default gen_random_uuid(),
  destinataire_id  uuid not null references public.profils(id) on delete cascade,
  titre            text not null,
  message          text not null,
  type             text,
  lu               boolean not null default false,
  created_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Règles de l'établissement (ligne unique id = 1)
-- ---------------------------------------------------------------------
create table if not exists public.regles (
  id                  int primary key default 1 check (id = 1),
  seuil_exclusion     int not null default 5 check (seuil_exclusion > 0),
  fenetre_pointage    int not null default 15 check (fenetre_pointage between 1 and 120),
  renouvellement_qr   int not null default 30 check (renouvellement_qr between 10 and 300),
  visage_obligatoire  boolean not null default true,
  seuil_visage        float8 not null default 1.0 check (seuil_visage > 0),
  updated_at          timestamptz not null default now()
);
insert into public.regles (id) values (1) on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Journal d'audit (alimenté uniquement par triggers / fonctions)
-- ---------------------------------------------------------------------
create table if not exists public.audit_log (
  id           bigint generated always as identity primary key,
  acteur_id    uuid references public.profils(id) on delete set null,
  action       text not null,
  table_cible  text,
  cible_id     text,
  details      jsonb not null default '{}'::jsonb,
  motif        text,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Index
-- ---------------------------------------------------------------------
create index if not exists idx_cours_enseignant on public.cours(enseignant_id);
create index if not exists idx_cours_classe on public.cours(classe);
create index if not exists idx_seances_cours_date on public.seances(cours_id, date);
create index if not exists idx_seances_date on public.seances(date);
create index if not exists idx_presences_etudiant on public.presences(etudiant_id);
create index if not exists idx_qr_tokens_seance on public.qr_tokens(seance_id, expire_a);
create index if not exists idx_tickets_etudiant on public.tickets_pointage(etudiant_id);
create index if not exists idx_profils_classe on public.profils(classe) where role = 'etudiant';
create index if not exists idx_notifications_dest on public.notifications(destinataire_id, created_at desc);
create index if not exists idx_audit_date on public.audit_log(created_at desc);

-- ---------------------------------------------------------------------
-- Création automatique du profil à l'inscription
-- Les comptes enseignant/directeur créés depuis l'application sont
-- INACTIFS jusqu'à activation par le directeur (sinon n'importe qui
-- pourrait s'inscrire comme directeur).
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_role text := coalesce(new.raw_user_meta_data->>'role', 'etudiant');
begin
  if v_role not in ('etudiant', 'enseignant', 'directeur') then
    v_role := 'etudiant';
  end if;
  insert into public.profils (id, nom, email, role, classe, actif)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data->>'nom'), ''), split_part(new.email, '@', 1)),
    new.email,
    v_role,
    nullif(trim(new.raw_user_meta_data->>'classe'), ''),
    v_role = 'etudiant'
  );
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
