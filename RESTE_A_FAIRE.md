# Reste à faire

## Corrigé dans cette version

### Base de données Supabase (`006_corrections.sql`, appliquée sur le projet)
- Table `presences` incomplète en ligne : colonnes `valide_par`, `pointe_a`, `distance`,
  `created_at`, `updated_at` absentes et **aucune contrainte `unique (seance, étudiant)`**.
  `valider_pointage` et `cloturer_seance` échouaient, et la base ne bloquait pas le double pointage.
- `authenticated` n'avait **aucun droit SELECT** sur `cours`, `seances` et `regles` : les accueils
  et l'emploi du temps restaient en erreur.
- `TRUNCATE` accordé à `authenticated` sur toutes les tables (contourne la RLS) : retiré.
- Un étudiant pouvait changer sa `classe` (et lire une autre classe) : désormais réservé au directeur.
- Fonctions de trigger exposées via `/rest/v1/rpc` et `search_path` non fixé : corrigés.
- Plus aucune séance après le 20/11 : emploi du temps régénéré sur 8 semaines, séances oubliées
  clôturées automatiquement (`cloturer_seances_passees`).

### Application
- `assets/models/mobilefacenet.tflite` était **vide (0 octet)** : l'application tournait en mode
  démo. Le vrai modèle (1×112×112×3 → 1×192) est maintenant fourni.
- Reconnaissance plus précise : alignement sur les yeux, contrôles de qualité, image + miroir,
  vote sur les 5 captures, cohérence de l'enregistrement, visage déjà utilisé refusé (voir README).
- Vivacité renforcée : défi au hasard (clignement / rotation) et validité limitée à 8 s.
- Plugin Android Gradle 8.7.3 → 9.1.0 et Kotlin 2.1.0 → 2.4.0 (exigés par Flutter 3.47).
- Sprint 2 complet (étudiant, enseignant, directeur).

## À vérifier sur téléphone (impossible depuis l'environnement de développement)

- [ ] Dérouler le scénario complet (étapes 1 à 20) avec 2 téléphones (enseignant + étudiant)
- [ ] **Calibrer le seuil du visage** : noter dans `audit_log` (`details->>'distance'`) les
      distances des pointages acceptés et refusés. Avec l'alignement, une même personne donne en
      général 0,5 à 0,9 et deux personnes différentes plus de 1,1. Ajuster `seuil_visage` dans
      Règles si besoin.
- [ ] Réenregistrer les visages des comptes de test : les captures faites en mode démo ne sont
      pas compatibles avec le vrai modèle (Profil → Mon visage → Refaire).
- [ ] Export : vérifier le partage du PDF / CSV vers Drive, Gmail, etc.

## Écarts assumés par rapport aux maquettes

- `valider_pointage(ticket_id, methode, embedding, vivacite)` : comparaison du visage **côté
  serveur**, plus sûre qu'une comparaison sur le téléphone.
- Absence justifiée = statut `absent` + `justifiee = true` (elle ne compte plus dans le seuil).
- Recours : après un refus de l'enseignant, l'étudiant peut transmettre au directeur, dont la
  décision est finale.
- La classe n'est plus modifiable par l'étudiant dans « Mon profil » (sécurité).
- Création de compte par le directeur : mot de passe provisoire saisi par le directeur.
- PDF : police Helvetica intégrée (accents latins pris en charge, pas d'emoji).

## Pistes d'amélioration

- Envoyer des notifications push (FCM) en plus des notifications dans l'application.
- Planifier `cloturer_seances_passees()` avec `pg_cron` au lieu de l'appeler à l'ouverture de l'accueil.
- Activer « Leaked password protection » dans Supabase (Authentication → Policies).
