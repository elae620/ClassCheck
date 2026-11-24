-- =====================================================================
-- ClassCheck — 008 : clôture automatique + données de test Sprint 2
--   - cloturer_seances_passees() : les séances oubliées (date passée,
--     jamais clôturées) passent en « clôturée », non-pointés → absent.
--   - 2e enseignante (Mme Salma, Réseaux), emploi du temps sur 8 semaines,
--     une réclamation et une auto-déclaration de démonstration.
-- Réexécutable. ⚠ Données de test : ne pas exécuter en production.
-- =====================================================================

create or replace function public.cloturer_seances_passees()
returns int language plpgsql security definer set search_path = public as $$
declare
  v record;
  v_nb int := 0;
begin
  if auth.uid() is not null and public.mon_role() not in ('enseignant', 'directeur') then
    raise exception 'acces_refuse';
  end if;
  for v in
    select s.id, c.classe from public.seances s join public.cours c on c.id = s.cours_id
    where s.statut <> 'cloturee'
      and (s.date + s.heure_fin) < (now() at time zone 'Africa/Tunis')
      and (auth.uid() is null or public.est_directeur() or c.enseignant_id = auth.uid())
  loop
    insert into public.presences (seance_id, etudiant_id, statut, methode)
    select v.id, p.id, 'absent', 'auto_cloture'
    from public.profils p
    where p.role = 'etudiant' and p.actif and p.classe = v.classe
    on conflict (seance_id, etudiant_id) do nothing;
    update public.seances set statut = 'cloturee', cloturee_a = now() where id = v.id;
    delete from public.qr_tokens where seance_id = v.id;
    insert into public.audit_log (acteur_id, action, table_cible, cible_id, details)
    values (auth.uid(), 'seance_cloturee', 'seances', v.id::text, '{"automatique": true}');
    v_nb := v_nb + 1;
  end loop;
  return v_nb;
end $$;
revoke execute on function public.cloturer_seances_passees() from public, anon;
grant execute on function public.cloturer_seances_passees() to authenticated;

-- ---------------------------------------------------------------------
-- Données de test
-- ---------------------------------------------------------------------
delete from auth.users where email = 'salma@ecole.tn';
do $$
declare
  v_id constant uuid := '00000000-0000-4000-a000-000000000003';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
    'salma@ecole.tn', extensions.crypt('Test1234!', extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"nom":"Mme Salma","role":"enseignant"}'::jsonb, now(), now(), '', '', '', ''
  );
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at)
  values (gen_random_uuid(), v_id, v_id::text,
          jsonb_build_object('sub', v_id::text, 'email', 'salma@ecole.tn', 'email_verified', true),
          'email', now(), now());
  perform set_config('app.motif', 'Données de test', true);
  update public.profils set actif = true where id = v_id;
end $$;

-- BD avancées : enseignée par Mme Salma (comme sur les maquettes) ; nouveau cours Réseaux.
update public.cours set enseignant_id = '00000000-0000-4000-a000-000000000003'
where code = 'BDA-DSI2';
insert into public.cours (id, code, nom, nom_court, classe, salle, enseignant_id) values
  ('00000000-0000-4000-b000-000000000003', 'RES-DSI2', 'Réseaux informatiques', 'Réseaux',
   'DSI 2', 'Salle C3', '00000000-0000-4000-a000-000000000003')
on conflict (id) do nothing;

-- Séances passées oubliées → clôturées.
select public.cloturer_seances_passees();

-- Emploi du temps : semaine en cours + 8 semaines.
--   Flutter du lundi au samedi 10:00–12:00 (une séance chaque jour ouvré : pratique pour tester)
--   BD mar/jeu 14:00–16:00, Réseaux lun/mer 08:30–10:00.
with jours as (
  select d::date as d, extract(isodow from d)::int as dow
  from generate_series(public.aujourdhui()::timestamp,
                       (public.aujourdhui() + 56)::timestamp, interval '1 day') d
),
plan as (
  select d, '00000000-0000-4000-b000-000000000001'::uuid c, time '10:00' hd, time '12:00' hf, 'Salle B2' salle
  from jours where dow between 1 and 6
  union all
  select d, '00000000-0000-4000-b000-000000000002'::uuid, time '14:00', time '16:00', 'Salle A1'
  from jours where dow in (2, 4)
  union all
  select d, '00000000-0000-4000-b000-000000000003'::uuid, time '08:30', time '10:00', 'Salle C3'
  from jours where dow in (1, 3)
)
insert into public.seances (cours_id, date, heure_debut, heure_fin, salle)
select p.c, p.d, p.hd, p.hf, p.salle from plan p
where not exists (select 1 from public.seances s
                  where s.cours_id = p.c and s.date = p.d and s.heure_debut = p.hd);

-- Historique Réseaux (3 semaines passées, clôturées) pour les statistiques.
with jours as (
  select d::date as d from generate_series((public.aujourdhui() - 21)::timestamp,
                                           (public.aujourdhui() - 1)::timestamp, interval '1 day') d
  where extract(isodow from d) in (1, 3)
)
insert into public.seances (cours_id, date, heure_debut, heure_fin, salle, statut,
                            ouverte_a, fenetre_minutes, cloturee_a)
select '00000000-0000-4000-b000-000000000003', j.d, '08:30', '10:00', 'Salle C3', 'cloturee',
       (j.d + time '08:30') at time zone 'Africa/Tunis', 15, (j.d + time '10:00') at time zone 'Africa/Tunis'
from jours j
where not exists (select 1 from public.seances s
                  where s.cours_id = '00000000-0000-4000-b000-000000000003' and s.date = j.d);

insert into public.presences (seance_id, etudiant_id, statut, methode, pointe_a)
select s.id, e.id,
       case when e.id = '00000000-0000-4000-a000-000000000013' and extract(isodow from s.date) = 1
            then 'absent' else 'present' end,
       case when e.id = '00000000-0000-4000-a000-000000000013' and extract(isodow from s.date) = 1
            then 'auto_cloture' else 'qr_visage' end,
       case when e.id = '00000000-0000-4000-a000-000000000013' and extract(isodow from s.date) = 1
            then null else ((s.date + time '08:33') at time zone 'Africa/Tunis') end
from public.seances s
cross join (values ('00000000-0000-4000-a000-000000000011'::uuid),
                   ('00000000-0000-4000-a000-000000000012'::uuid),
                   ('00000000-0000-4000-a000-000000000013'::uuid)) e(id)
where s.cours_id = '00000000-0000-4000-b000-000000000003' and s.statut = 'cloturee'
on conflict (seance_id, etudiant_id) do nothing;

-- Une réclamation en attente (Sara, sa dernière absence) et une auto-déclaration (Omar).
delete from public.reclamations where etudiant_id in
  ('00000000-0000-4000-a000-000000000012', '00000000-0000-4000-a000-000000000013');
delete from public.auto_declarations where etudiant_id = '00000000-0000-4000-a000-000000000013';

insert into public.reclamations (presence_id, etudiant_id, motif)
select p.id, p.etudiant_id, 'J''étais malade, voici mon certificat médical.'
from public.presences p join public.seances s on s.id = p.seance_id
where p.etudiant_id = '00000000-0000-4000-a000-000000000012' and p.statut = 'absent'
order by s.date desc limit 1;

insert into public.auto_declarations (seance_id, etudiant_id, type, motif)
select s.id, '00000000-0000-4000-a000-000000000013', 'retard', 'Problème de transport'
from public.seances s
where s.cours_id = '00000000-0000-4000-b000-000000000001' and s.date = public.aujourdhui()
limit 1;

select c.nom_court, count(*) filter (where s.date >= public.aujourdhui()) as a_venir,
       count(*) filter (where s.statut = 'cloturee') as cloturees
from public.cours c join public.seances s on s.cours_id = c.id group by c.nom_court;
