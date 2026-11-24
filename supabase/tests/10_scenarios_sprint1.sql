\set ON_ERROR_STOP 0
\pset tuples_only on
\pset format unaligned
-- Identifiants
\set ali   '00000000-0000-4000-a000-000000000011'
\set sara  '00000000-0000-4000-a000-000000000012'
\set omar  '00000000-0000-4000-a000-000000000013'
\set karim '00000000-0000-4000-a000-000000000002'

-- Vecteurs de test : A (Ali), B (visage différent), normalisés
create temp table vec as
select (select array_agg(v / sqrt((select sum(x*x) from (select ((i % 7) + 1)::float8 x from generate_series(1,192) i) s)) order by i)
        from (select i, ((i % 7) + 1)::float8 v from generate_series(1,192) i) a) as a,
       (select array_agg((case when i % 2 = 0 then -1 else 1 end)::float8 / sqrt(192) order by i)
        from generate_series(1,192) i) as b;
grant select on vec to authenticated;
select id as seance_flutter from seances s where cours_id='00000000-0000-4000-b000-000000000001' and date = aujourdhui() \gset

\echo '--- Enregistrement des visages (Ali = A, Sara = A aussi pour tester le mauvais visage avec B)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'ali' || '"}', true);
select 'ali visage : ' || enregistrer_visage((select a||a||a||a||a from vec)); commit;
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'sara' || '"}', true);
select 'sara visage : ' || enregistrer_visage((select a||a||a||a||a from vec)); commit;
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'sara' || '"}', true);
select 'enregistrer 3 captures -> ' || enregistrer_visage((select a||a||a from vec)); rollback;

\echo '--- Ali tente d''ouvrir la séance (doit échouer)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'ali' || '"}', true);
select ouvrir_seance(:'seance_flutter'); rollback;

\echo '--- Scan avant ouverture'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'ali' || '"}', true);
select 'avant ouverture : ' || scanner_qr(:'seance_flutter', 'x')::text; commit;

\echo '--- Karim ouvre la séance (15 min, visage) et génère un QR'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'karim' || '"}', true);
select 'ouverte : ' || (ouvrir_seance(:'seance_flutter', 15, true)->>'statut');
select generer_qr(:'seance_flutter')->>'token' as tok \gset
commit;

\echo '=== TEST 4 : cas normal (Ali, bon QR, bon visage, vivacité)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'ali' || '"}', true);
select scanner_qr(:'seance_flutter', :'tok') as r1 \gset
select 'scan : ' || :'r1';
select (:'r1'::json->>'ticket_id') as ticket_ali \gset
select 'validation : ' || valider_pointage(:'ticket_ali', 'qr_visage', (select a from vec), true)::text; commit;

\echo '=== TEST 8 : double pointage'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'ali' || '"}', true);
select 'rescan : ' || scanner_qr(:'seance_flutter', :'tok')::text;
select 'ticket réutilisé : ' || valider_pointage(:'ticket_ali', 'qr_visage', (select a from vec), true)::text; commit;

\echo '=== TEST 5 : QR expiré (Sara)'
begin; insert into qr_tokens(seance_id, token, expire_a) values (:'seance_flutter', 'ancien0000000000000000000000000f', now() - interval '5 seconds'); commit;
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'sara' || '"}', true);
select 'qr expiré : ' || scanner_qr(:'seance_flutter', 'ancien0000000000000000000000000f')::text;
select 'qr inventé : ' || scanner_qr(:'seance_flutter', 'deadbeef')::text; commit;

\echo '=== TEST 6 : mauvais visage (Sara présente le visage B)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'sara' || '"}', true);
select scanner_qr(:'seance_flutter', :'tok')->>'ticket_id' as ticket_sara \gset
select 'mauvais visage : ' || valider_pointage(:'ticket_sara', 'qr_visage', (select b from vec), true)::text; commit;

\echo '=== TEST 7 : photo (pas de vivacité) + contournement sans visage'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'sara' || '"}', true);
select 'sans vivacité : ' || valider_pointage(:'ticket_sara', 'qr_visage', (select a from vec), false)::text;
select 'méthode qr seule : ' || valider_pointage(:'ticket_sara', 'qr', null, false)::text;
select '4e essai : ' || valider_pointage(:'ticket_sara', 'qr_visage', (select a from vec), true)::text; commit;

\echo '--- Ticket d''un autre étudiant (Omar utilise le ticket de Sara)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'omar' || '"}', true);
select 'vol de ticket : ' || valider_pointage(:'ticket_sara', 'qr_visage', (select a from vec), true)::text; commit;

\echo '--- Ticket expiré (> 2 min)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'sara' || '"}', true);
select scanner_qr(:'seance_flutter', :'tok')->>'ticket_id' as ticket_sara2 \gset
commit;
begin; update tickets_pointage set expire_a = now() - interval '1 second' where id = :'ticket_sara2'; commit;
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'sara' || '"}', true);
select 'ticket expiré : ' || valider_pointage(:'ticket_sara2', 'qr_visage', (select a from vec), true)::text; commit;

\echo '=== TEST 9 : hors fenêtre'
begin; update seances set ouverte_a = now() - interval '20 minutes' where id = :'seance_flutter'; commit;
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'sara' || '"}', true);
select 'hors fenêtre : ' || scanner_qr(:'seance_flutter', :'tok')::text; commit;
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'karim' || '"}', true);
select generer_qr(:'seance_flutter'); rollback;

\echo '=== TEST 10 : clôture puis scan'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'karim' || '"}', true);
select 'clôture : ' || cloturer_seance(:'seance_flutter')::text; commit;
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'sara' || '"}', true);
select 'après clôture : ' || scanner_qr(:'seance_flutter', :'tok')::text; commit;
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"' || :'karim' || '"}', true);
select cloturer_seance(:'seance_flutter'); rollback;
select 'statuts : ' || string_agg(p.nom || '=' || pr.statut || '/' || pr.methode, ', ' order by p.nom)
from presences pr join profils p on p.id = pr.etudiant_id where seance_id = :'seance_flutter';
