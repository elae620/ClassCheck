# Tests SQL (PostgreSQL local, hors Supabase)

Scripts utilisés pour vérifier les migrations sans toucher au projet Supabase :

1. Créer une base locale vide, exécuter `00_mock_supabase_local.sql` (simule `auth`, les rôles
   `anon`/`authenticated` et `auth.uid()`).
2. Exécuter les migrations `001` → `005`.
3. Exécuter `10_scenarios_sprint1.sql` (tests 4 à 10) puis `20_rls.sql` (isolation des données).

⚠ Ne pas exécuter `00_mock_supabase_local.sql` dans Supabase : le schéma `auth` y existe déjà.

## Tests directement dans Supabase

`30_scenarios_supabase.sql` peut être collé dans le **SQL Editor de Supabase** (migrations 001 → 008
exécutées). Il rejoue les tests 4 à 10 du scénario, la RLS, l'enregistrement du visage (captures
incohérentes, visage déjà utilisé), l'auto-déclaration, la correction avec motif et le circuit
réclamation → recours → décision du directeur. Tout est **annulé** à la fin : le compte rendu
s'affiche dans le message d'erreur « RESULTATS (annulés) ».
