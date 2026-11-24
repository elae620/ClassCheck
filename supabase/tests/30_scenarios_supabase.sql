-- =====================================================================
-- Tests de bout en bout EXÉCUTABLES DANS SUPABASE (SQL Editor), sans
-- laisser de trace : tout est annulé à la fin (exception volontaire) et
-- le compte rendu s'affiche dans le message d'erreur « RESULTATS ».
-- Prérequis : migrations 001 → 008 exécutées.
-- =====================================================================
do $$
declare
  ali   constant uuid := '00000000-0000-4000-a000-000000000011';
  sara  constant uuid := '00000000-0000-4000-a000-000000000012';
  omar  constant uuid := '00000000-0000-4000-a000-000000000013';
  karim constant uuid := '00000000-0000-4000-a000-000000000002';
  dir   constant uuid := '00000000-0000-4000-a000-000000000001';
  va float8[]; vb float8[]; vproche float8[];
  s_id uuid; tok text; r json; ticket uuid; n int; rec_id uuid; decl_id uuid;
  out text := '';
  procedure_ok boolean;

  -- (les sous-procédures ne sont pas possibles en DO : on utilise des blocs)
begin
  -- Vecteurs de test normalisés : A (Ali), B (autre personne), A' (Ali, légère variation)
  select array_agg(((i % 7) + 1)::float8 / sqrt((select sum(((j % 7) + 1)^2) from generate_series(1,192) j)) order by i)
    into va from generate_series(1,192) i;
  select array_agg((case when i % 2 = 0 then -1 else 1 end)::float8 / sqrt(192) order by i)
    into vb from generate_series(1,192) i;
  select array_agg(va[i] + case when i % 5 = 0 then 0.01 else 0 end order by i) into vproche
    from generate_series(1,192) i;

  select id into s_id from public.seances
  where cours_id = '00000000-0000-4000-b000-000000000001' and date = public.aujourdhui();
  -- Séance de test « propre » (au cas où elle aurait déjà servi)
  delete from public.presences where seance_id = s_id;
  update public.seances set statut = 'planifiee', ouverte_a = null, fenetre_minutes = null where id = s_id;

  -- ---------------- Enregistrement des visages ----------------
  perform set_config('request.jwt.claims', json_build_object('sub', ali)::text, true);
  execute 'set local role authenticated';
  perform public.enregistrer_visage(va || va || va || vproche || va);
  out := out || E'\nvisage Ali : OK';
  begin
    perform public.enregistrer_visage(va || va || va || va || vb);
    out := out || E'\nKO captures incohérentes acceptées';
  exception when others then out := out || E'\ncaptures incohérentes -> ' || sqlerrm; end;
  execute 'reset role';

  perform set_config('request.jwt.claims', json_build_object('sub', sara)::text, true);
  execute 'set local role authenticated';
  begin
    perform public.enregistrer_visage(va || va || va || va || va);
    out := out || E'\nKO visage d''Ali accepté pour Sara';
  exception when others then out := out || E'\nSara avec le visage d''Ali -> ' || sqlerrm; end;
  perform public.enregistrer_visage(vb || vb || vb || vb || vb);
  out := out || E'\nvisage Sara : OK';
  execute 'reset role';

  -- ---------------- Ouverture + QR ----------------
  perform set_config('request.jwt.claims', json_build_object('sub', ali)::text, true);
  execute 'set local role authenticated';
  out := out || E'\navant ouverture : ' || public.scanner_qr(s_id, 'x')::text;
  begin perform public.ouvrir_seance(s_id); out := out || E'\nKO étudiant ouvre';
  exception when others then out := out || E'\nétudiant ouvre -> ' || sqlerrm; end;
  execute 'reset role';

  perform set_config('request.jwt.claims', json_build_object('sub', karim)::text, true);
  execute 'set local role authenticated';
  perform public.ouvrir_seance(s_id, 15, true);
  tok := public.generer_qr(s_id)->>'token';
  execute 'reset role';

  -- ---------------- TEST 4 : cas normal ----------------
  perform set_config('request.jwt.claims', json_build_object('sub', ali)::text, true);
  execute 'set local role authenticated';
  r := public.scanner_qr(s_id, tok);
  ticket := (r->>'ticket_id')::uuid;
  out := out || E'\nT4 scan : ' || (r->>'ok') || E'\nT4 validation : '
             || public.valider_pointage(ticket, 'qr_visage', vproche, true)::text;
  -- TEST 8 : double pointage
  out := out || E'\nT8 rescan : ' || public.scanner_qr(s_id, tok)::text;
  out := out || E'\nT8 ticket réutilisé : ' || public.valider_pointage(ticket, 'qr_visage', va, true)::text;
  execute 'reset role';

  -- ---------------- TEST 5 : QR expiré ----------------
  insert into public.qr_tokens(seance_id, token, expire_a)
  values (s_id, 'ancien0000000000000000000000000f', now() - interval '5 seconds');
  perform set_config('request.jwt.claims', json_build_object('sub', sara)::text, true);
  execute 'set local role authenticated';
  out := out || E'\nT5 qr expiré : ' || public.scanner_qr(s_id, 'ancien0000000000000000000000000f')::text;
  out := out || E'\nT5 qr inventé : ' || public.scanner_qr(s_id, 'deadbeef')::text;

  -- ---------------- TEST 6 : mauvais visage ; TEST 7 : photo (pas de vivacité) ----------------
  r := public.scanner_qr(s_id, tok);
  ticket := (r->>'ticket_id')::uuid;
  out := out || E'\nT6 mauvais visage : ' || public.valider_pointage(ticket, 'qr_visage', va, true)::text;
  out := out || E'\nT7 sans vivacité : ' || public.valider_pointage(ticket, 'qr_visage', vb, false)::text;
  out := out || E'\nT7 sans visage (qr seul) : ' || public.valider_pointage(ticket, 'qr', null, false)::text;
  out := out || E'\n3e essai (bon visage) : ' || public.valider_pointage(ticket, 'qr_visage', vb, true)::text;

  -- ---------------- RLS ----------------
  select count(*) into n from public.presences where etudiant_id <> sara;
  out := out || E'\nRLS présences des autres vues par Sara : ' || n;
  select count(*) into n from public.qr_tokens;
  out := out || E'\nRLS jetons vus par Sara : ' || n;
  begin
    perform face_embedding from public.profils limit 1;
    out := out || E'\nKO embedding lisible';
  exception when others then out := out || E'\nRLS embedding -> ' || sqlerrm; end;
  begin
    update public.profils set classe = 'DSI 3' where id = sara;
    out := out || E'\nKO changement de classe autorisé';
  exception when others then out := out || E'\nchangement de classe -> ' || sqlerrm; end;
  begin
    insert into public.presences (seance_id, etudiant_id, statut, methode) values (s_id, sara, 'present', 'manuel');
    out := out || E'\nKO insertion directe de présence';
  exception when others then out := out || E'\ninsertion directe -> ' || sqlerrm; end;
  execute 'reset role';

  -- ---------------- TEST 9 : hors fenêtre ----------------
  update public.seances set ouverte_a = now() - interval '16 minutes' where id = s_id;
  perform set_config('request.jwt.claims', json_build_object('sub', omar)::text, true);
  execute 'set local role authenticated';
  out := out || E'\nT9 hors fenêtre : ' || public.scanner_qr(s_id, tok)::text;
  execute 'reset role';
  update public.seances set ouverte_a = now() where id = s_id;

  -- ---------------- Sprint 2 : auto-déclaration (Omar, retard) ----------------
  select id into decl_id from public.auto_declarations where seance_id = s_id and etudiant_id = omar;
  perform set_config('request.jwt.claims', json_build_object('sub', omar)::text, true);
  execute 'set local role authenticated';
  begin perform public.traiter_auto_declaration(decl_id, true, 'ok');
    out := out || E'\nKO étudiant valide sa déclaration';
  exception when others then out := out || E'\nétudiant valide -> ' || sqlerrm; end;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', karim)::text, true);
  execute 'set local role authenticated';
  out := out || E'\nauto-déclaration validée : ' || (public.traiter_auto_declaration(decl_id, true, null)->>'statut');
  select statut into tok from public.presences where seance_id = s_id and etudiant_id = omar;
  out := out || E'\n  -> présence Omar : ' || coalesce(tok, 'aucune');

  -- Correction manuelle sans motif / avec motif
  begin perform public.corriger_presence(s_id, sara, 'present', '  ');
    out := out || E'\nKO correction sans motif';
  exception when others then out := out || E'\ncorrection sans motif -> ' || sqlerrm; end;
  out := out || E'\ncorrection Sara : ' || (public.corriger_presence(s_id, sara, 'present', 'caméra en panne')->>'statut');

  -- ---------------- TEST 10 : clôture ----------------
  r := public.cloturer_seance(s_id);
  out := out || E'\nT10 clôture : ' || r::text;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', ali)::text, true);
  execute 'set local role authenticated';
  out := out || E'\nT10 scan après clôture : ' || public.scanner_qr(s_id, tok)::text;
  execute 'reset role';

  -- ---------------- Réclamation : refus → recours → décision du directeur ----------------
  select id into rec_id from public.reclamations where etudiant_id = sara and statut = 'en_attente' limit 1;
  select c.enseignant_id into ticket from public.reclamations r2
    join public.presences p on p.id = r2.presence_id join public.seances s on s.id = p.seance_id
    join public.cours c on c.id = s.cours_id where r2.id = rec_id;
  perform set_config('request.jwt.claims', json_build_object('sub', ticket)::text, true);
  execute 'set local role authenticated';
  out := out || E'\nréclamation refusée par l''enseignant : '
             || (public.traiter_reclamation(rec_id, 'refusee', 'Le certificat ne couvre pas la date.')->>'statut');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', sara)::text, true);
  execute 'set local role authenticated';
  out := out || E'\nrecours de Sara : ' || (public.contester_reclamation(rec_id, 'Je conteste')->>'statut');
  select count(*) into n from public.notifications where destinataire_id = sara;
  out := out || E'\nnotifications de Sara : ' || n;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', dir)::text, true);
  execute 'set local role authenticated';
  out := out || E'\ndécision du directeur : ' || (public.traiter_reclamation(rec_id, 'acceptee', 'Certificat valable')->>'statut');
  select count(*) into n from public.audit_log where action in ('decision_reclamation', 'correction_presence', 'decision_auto_declaration');
  out := out || E'\nlignes d''audit (corrections + décisions) : ' || n;
  out := out || E'\nstats directeur : taux=' || (public.stats_presences()->>'taux')
             || ' à risque=' || (select count(distinct etudiant_id) from public.etudiants_a_risque());
  execute 'reset role';

  raise exception 'RESULTATS (annulés) :%', out;
end $$;
