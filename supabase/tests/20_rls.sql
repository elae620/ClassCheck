\pset tuples_only on
\pset format unaligned
\set ali   '00000000-0000-4000-a000-000000000011'
\set sara  '00000000-0000-4000-a000-000000000012'
\set karim '00000000-0000-4000-a000-000000000002'
\set dir   '00000000-0000-4000-a000-000000000001'
create temp table vec2 as select array_agg((case when i % 2 = 0 then -1 else 1 end)::float8 / sqrt(192) order by i) b from generate_series(1,192) i;
grant select on vec2 to authenticated;
select id as seance_bd from seances where cours_id='00000000-0000-4000-b000-000000000002' and date = aujourdhui() \gset

\echo '--- Ticket expiré et limite de 3 essais (séance BD)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'karim' || '"}', true);
select ouvrir_seance(:'seance_bd', 10, false)->>'visage_obligatoire' as visage_force;
select generer_qr(:'seance_bd')->>'token' as tok \gset
commit;
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'sara' || '"}', true);
select scanner_qr(:'seance_bd', :'tok')->>'ticket_id' as t1 \gset
commit;
update tickets_pointage set expire_a = now() - interval '1 second' where id = :'t1';
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'sara' || '"}', true);
select 'ticket expiré : ' || valider_pointage(:'t1', 'qr_visage', (select b from vec2), true)::text;
select scanner_qr(:'seance_bd', :'tok')->>'ticket_id' as t2 \gset
commit;
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'sara' || '"}', true);
select 'essai ' || g || ' : ' || (valider_pointage(:'t2', 'qr_visage', (select b from vec2), true)->>'erreur') from generate_series(1,4) g;
commit;

\echo '=== RLS : étudiant Ali'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'ali' || '"}', true);
select 'profils visibles : ' || string_agg(nom, ', ' order by nom) from profils;
select 'présences d''autres étudiants visibles : ' || count(*) from presences where etudiant_id <> :'ali';
select 'mes présences : ' || count(*) from presences;
select 'qr_tokens visibles : ' || count(*) from qr_tokens;
select 'tickets d''autres : ' || count(*) from tickets_pointage where etudiant_id <> :'ali';
select 'audit visible : ' || count(*) from audit_log;
select 'cours visibles : ' || count(*) from cours;
commit;
\echo '--- Ali lit son embedding (doit être refusé)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'ali' || '"}', true);
select face_embedding from profils where id = :'ali'; rollback;
\echo '--- Ali se promeut directeur (doit être refusé)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'ali' || '"}', true);
update profils set role = 'directeur' where id = :'ali'; rollback;
\echo '--- Ali insère une présence à la main (doit être refusé)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'ali' || '"}', true);
insert into presences(seance_id, etudiant_id, statut, methode) values (:'seance_bd', :'ali', 'present', 'qr'); rollback;
\echo '--- Ali modifie le nom de Sara (0 ligne attendue)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'ali' || '"}', true);
with u as (update profils set nom = 'pirate' where id = :'sara' returning 1) select 'lignes modifiées : ' || count(*) from u; rollback;
\echo '--- Ali modifie son propre nom (autorisé)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'ali' || '"}', true);
with u as (update profils set nom = 'Ali B. Salah' where id = :'ali' returning 1) select 'lignes modifiées : ' || count(*) from u; rollback;
\echo '--- Anonyme'
begin; set local role anon; select count(*) from seances; rollback;

\echo '=== RLS : enseignant Karim'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'karim' || '"}', true);
select 'étudiants visibles : ' || count(*) from profils where role = 'etudiant';
select 'présences visibles : ' || count(*) from presences;
select 'audit visible : ' || count(*) from audit_log;
commit;
\echo '--- Correction manuelle sans motif (doit être refusée par le trigger)'
update presences set statut = 'retard' where seance_id = :'seance_bd';
select 'présents BD : ' || count(*) from presences where seance_id = :'seance_bd';
update presences set statut='absent' where id = (select id from presences where statut='present' limit 1);
begin; select set_config('app.motif', 'caméra en panne', true);
update presences set statut='retard' where id = (select id from presences where statut='present' order by created_at limit 1);
commit;
select 'audit correction : ' || action || ' / motif=' || motif from audit_log where action='correction_presence';

\echo '=== Directeur'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'dir' || '"}', true);
select 'audit visible : ' || count(*) || ' lignes, actions=' || string_agg(distinct action, ',') from audit_log;
select 'profils visibles : ' || count(*) from profils;
commit;

\echo '=== Inscription libre comme directeur (doit créer un compte INACTIF)'
insert into auth.users(id, email, raw_user_meta_data) values (gen_random_uuid(), 'faux@ecole.tn', '{"nom":"Faux","role":"directeur"}');
select 'faux directeur actif ? ' || actif from profils where email='faux@ecole.tn';
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || (select id from profils where email='faux@ecole.tn') || '"}', true);
select 'il voit l''audit : ' || count(*) from audit_log; select 'est_directeur : ' || est_directeur(); commit;
