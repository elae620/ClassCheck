-- =====================================================================
-- ClassCheck — 005 : données de test (réexécutable)
--   1 directeur, 1 enseignant, 3 étudiants (DSI 2), 2 cours,
--   séances des 3 dernières semaines (clôturées, avec présences)
--   + séances du jour et de la fin de semaine (planifiées).
-- Mot de passe de tous les comptes : Test1234!
-- ⚠ À NE PAS exécuter sur une base de production.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Nettoyage des anciennes données de test
-- ---------------------------------------------------------------------
delete from public.cours where code in ('FLT-DSI2', 'BDA-DSI2');
delete from auth.users where email in (
  'directeur@ecole.tn', 'karim@ecole.tn',
  'ali@ecole.tn', 'sara@ecole.tn', 'omar@ecole.tn'
);

-- ---------------------------------------------------------------------
-- Comptes (auth.users + auth.identities ; le profil est créé par trigger)
-- ---------------------------------------------------------------------
do $$
declare
  u record;
begin
  for u in
    select * from (values
      ('00000000-0000-4000-a000-000000000001'::uuid, 'directeur@ecole.tn', 'M. Directeur',  'directeur',  null),
      ('00000000-0000-4000-a000-000000000002'::uuid, 'karim@ecole.tn',     'M. Karim',      'enseignant', null),
      ('00000000-0000-4000-a000-000000000011'::uuid, 'ali@ecole.tn',       'Ali Ben Salah', 'etudiant',   'DSI 2'),
      ('00000000-0000-4000-a000-000000000012'::uuid, 'sara@ecole.tn',      'Sara Mansouri', 'etudiant',   'DSI 2'),
      ('00000000-0000-4000-a000-000000000013'::uuid, 'omar@ecole.tn',      'Omar Haddad',   'etudiant',   'DSI 2')
    ) as t(id, email, nom, role, classe)
  loop
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated',
      u.email, extensions.crypt('Test1234!', extensions.gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_strip_nulls(jsonb_build_object('nom', u.nom, 'role', u.role, 'classe', u.classe)),
      now(), now(), '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), u.id, u.id::text,
      jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
      'email', now(), now(), now()
    );
  end loop;

  -- Les comptes de test enseignant/directeur sont actifs d'emblée.
  update public.profils set actif = true
  where id in ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000002');
end $$;

-- ---------------------------------------------------------------------
-- Cours
-- ---------------------------------------------------------------------
insert into public.cours (id, code, nom, nom_court, classe, salle, enseignant_id) values
  ('00000000-0000-4000-b000-000000000001', 'FLT-DSI2', 'Développement mobile Flutter',
   'Flutter', 'DSI 2', 'Salle B2', '00000000-0000-4000-a000-000000000002'),
  ('00000000-0000-4000-b000-000000000002', 'BDA-DSI2', 'Bases de données avancées',
   'BD avancées', 'DSI 2', 'Salle A1', '00000000-0000-4000-a000-000000000002');

-- ---------------------------------------------------------------------
-- Séances : Flutter lun/mer/ven 10:00–12:00, BD mar/jeu 14:00–16:00,
-- et les deux cours aujourd'hui quoi qu'il arrive (pour les tests).
-- ---------------------------------------------------------------------
with jours as (
  select d::date as d, extract(isodow from d)::int as dow
  from generate_series(
    (public.aujourdhui() - 21)::timestamp,
    (public.aujourdhui() + (7 - extract(isodow from public.aujourdhui())::int))::timestamp,
    interval '1 day'
  ) as d
),
plan as (
  select j.d, '00000000-0000-4000-b000-000000000001'::uuid as cours_id,
         time '10:00' as hd, time '12:00' as hf, 'Salle B2' as salle
  from jours j where j.dow in (1, 3, 5) or j.d = public.aujourdhui()
  union all
  select j.d, '00000000-0000-4000-b000-000000000002'::uuid,
         time '14:00', time '16:00', 'Salle A1'
  from jours j where j.dow in (2, 4) or j.d = public.aujourdhui()
)
insert into public.seances (cours_id, date, heure_debut, heure_fin, salle, statut,
                            ouverte_a, fenetre_minutes, visage_obligatoire, cloturee_a)
select
  p.cours_id, p.d, p.hd, p.hf, p.salle,
  case when p.d < public.aujourdhui() then 'cloturee' else 'planifiee' end,
  case when p.d < public.aujourdhui() then (p.d + p.hd) at time zone 'Africa/Tunis' end,
  case when p.d < public.aujourdhui() then 15 end,
  true,
  case when p.d < public.aujourdhui() then (p.d + p.hf) at time zone 'Africa/Tunis' end
from plan p;

-- ---------------------------------------------------------------------
-- Présences des séances passées (profils variés : Omar est « à risque »)
-- ---------------------------------------------------------------------
with passees as (
  select s.id, s.date, s.heure_debut,
         row_number() over (partition by s.cours_id order by s.date) as n
  from public.seances s
  where s.cours_id in ('00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-000000000002')
    and s.statut = 'cloturee'
),
grille as (
  select p.*, e.id as etudiant_id,
    case e.id
      when '00000000-0000-4000-a000-000000000011' then
        case when p.n % 7 = 3 then 'absent' when p.n % 5 = 4 then 'retard' else 'present' end
      when '00000000-0000-4000-a000-000000000012' then
        case when p.n % 8 = 2 then 'absent' else 'present' end
      else
        case when p.n % 2 = 0 then 'absent' else 'present' end
    end as statut
  from passees p
  cross join (values
    ('00000000-0000-4000-a000-000000000011'::uuid),
    ('00000000-0000-4000-a000-000000000012'::uuid),
    ('00000000-0000-4000-a000-000000000013'::uuid)
  ) as e(id)
)
insert into public.presences (seance_id, etudiant_id, statut, methode, pointe_a, valide_par)
select
  g.id, g.etudiant_id, g.statut,
  case g.statut when 'present' then 'qr_visage' when 'retard' then 'manuel' else 'auto_cloture' end,
  case when g.statut <> 'absent'
       then ((g.date + g.heure_debut) at time zone 'Africa/Tunis')
            + make_interval(mins => case g.statut when 'retard' then 18 else 3 end)
  end,
  case when g.statut = 'present' then null else '00000000-0000-4000-a000-000000000002'::uuid end
from grille g;

-- Vérification rapide
select role, nom, email, classe, actif from public.profils order by role, nom;
