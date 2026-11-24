# ClassCheck — gestion des absences (Flutter + Supabase)

Application mobile de gestion des absences pour un établissement scolaire, avec trois rôles
(étudiant, enseignant, directeur). Le pointage combine un **QR code dynamique renouvelé toutes
les 30 s** et une **vérification faciale avec test de vivacité** : un absent ne peut pas
déclarer sa présence à distance. Chaque étape est tracée dans un **journal d'audit**.

> État : **Sprints 1 et 2 terminés** : pointage, réclamations, supervision du directeur, export.
> La base Supabase a été corrigée (voir `006_corrections.sql`) et les scénarios sont testés côté
> serveur. Ce qui reste à vérifier sur téléphone est listé dans [`RESTE_A_FAIRE.md`](RESTE_A_FAIRE.md).

---

## 1. Prérequis

- Flutter stable (≥ 3.27, Dart ≥ 3.6) et Android Studio avec le plugin Flutter
- Un téléphone Android (caméra frontale + arrière) ou un émulateur avec webcam
- Un projet Supabase

## 2. Base de données Supabase

1. Ouvrir **SQL Editor** dans le tableau de bord Supabase.
2. Exécuter **dans l'ordre** les fichiers de `supabase/migrations/` :

| Fichier | Contenu |
|---|---|
| `001_tables.sql` | Tables, index, création automatique du profil à l'inscription |
| `002_rls.sql` | RLS sur toutes les tables, droits par colonne, Realtime sur `presences` |
| `003_rpc_pointage.sql` | `ouvrir_seance`, `generer_qr`, `scanner_qr`, `valider_pointage`, `cloturer_seance`, `compteur_seance`, `enregistrer_visage` |
| `004_audit.sql` | Triggers du journal d'audit (motif obligatoire) |
| `005_seed.sql` | Données de test (réexécutable) |
| `006_corrections.sql` | **Corrections** : colonnes/contraintes manquantes de `presences`, droits SELECT manquants (`cours`, `seances`, `regles`), retrait de TRUNCATE, classe non modifiable par l'étudiant, reconnaissance faciale plus stricte (vote, cohérence, visage déjà utilisé) |
| `007_sprint2.sql` | Sprint 2 : auto-déclarations, réclamations + bucket `justificatifs`, corrections, notifications, statistiques, gestion des comptes et des séances |
| `008_seed_sprint2.sql` | Clôture auto des séances oubliées + données de test (Mme Salma, Réseaux, 8 semaines de séances) |

3. *(Recommandé en développement)* **Authentication → Providers → Email** : désactiver
   « Confirm email », sinon chaque inscription attend un clic dans un e-mail.

Les scripts sont réexécutables (idempotents). Ils ont été testés sur PostgreSQL 16.

### Comptes de test (mot de passe : `Test1234!`)

| Rôle | E-mail | Remarque |
|---|---|---|
| Directeur | `directeur@ecole.tn` | |
| Enseignant | `karim@ecole.tn` | Cours « Flutter » (DSI 2), une séance chaque jour du lundi au samedi |
| Enseignante | `salma@ecole.tn` | « BD avancées » et « Réseaux » (DSI 2) |
| Étudiant | `ali@ecole.tn` | DSI 2 |
| Étudiant | `sara@ecole.tn` | DSI 2 |
| Étudiant | `omar@ecole.tn` | DSI 2, nombreuses absences (« à risque ») |

Les seeds créent l'historique des 3 dernières semaines et l'emploi du temps des **8 semaines
suivantes** (Flutter tous les jours ouvrés à 10:00, BD mar/jeu 14:00, Réseaux lun/mer 08:30).
Une séance du jour peut être ouverte à toute heure. Le directeur peut planifier d'autres séances
(Gestion → Emplois du temps). Au premier login, chaque étudiant **enregistre son visage**.

## 3. Configuration de l'application (aucune clé dans le code)

Les clés sont lues avec `--dart-define-from-file`. Le fichier `dart_defines.json` est
**ignoré par git** ; un modèle est fourni :

```bash
copy dart_defines.example.json dart_defines.json   # puis renseigner l'URL et la clé publishable
```

```json
{ "SUPABASE_URL": "https://xxxx.supabase.co", "SUPABASE_ANON_KEY": "sb_publishable_..." }
```

## 4. Installation et lancement

Le dépôt contient le code Dart, le manifeste Android et les tests. Les dossiers natifs générés
sont créés une seule fois par Flutter (les fichiers existants ne sont **pas** écrasés) :

```bash
cd C:\DSI31\CrossPlatf\miniProjet
flutter create --org tn.dsi --project-name classcheck --platforms=android .
```

Puis, dans `android/app/build.gradle.kts` (ou `build.gradle`), remplacer la ligne `minSdk` par :

```kotlin
minSdk = 26   // requis par tflite_flutter et ML Kit
```

Ensuite :

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=dart_defines.json
```

Dans Android Studio, la configuration d'exécution **« ClassCheck (main) »** (dossier `.run/`)
ajoute déjà `--dart-define-from-file=dart_defines.json`.

> Si Gradle demande une version de NDK précise (message « requires Android NDK … »),
> ajouter la ligne `ndkVersion = "…"` indiquée par le message dans le bloc `android { }`.

### Modèle de reconnaissance faciale

`assets/models/mobilefacenet.tflite` (MobileFaceNet, entrée 1×112×112×3 float32, sortie 1×192)
est fourni. S'il manque, l'application bascule sur une implémentation **factice** (badge
« Mode démo ») qui ne distingue pas fiablement deux personnes. Voir `assets/models/README.md`.

#### Précision de la reconnaissance (IA)

| Étape | Rôle |
|---|---|
| Contrôle de pose | visage de face (±15°), assez grand, yeux ouverts : sinon nouvelle photo, **sans consommer d'essai** |
| Alignement sur les yeux | yeux à l'horizontale, écart et hauteur fixes (comme les visages d'entraînement du modèle) |
| Netteté / éclairage | variance du laplacien et luminosité moyenne : photo floue ou sombre refusée |
| Image + miroir | moyenne des embeddings de la photo et de son miroir, puis normalisation L2 |
| Vote sur 5 captures | distance min ≤ seuil **et** au moins `votes_visage` (2) captures d'accord |
| Enregistrement | les 5 captures doivent se ressembler ; un visage déjà enregistré sur un autre compte est refusé |
| Vivacité | défi tiré au hasard (clignement / rotation de la tête), photo dans les 8 s suivant le geste |

Le seuil (`seuil_visage`, 1.0) et le nombre de votes sont réglables par le directeur (Règles).

## 5. Architecture

```
lib/
  core/        thème, routeur (go_router + redirections par rôle), Supabase,
               modèles partagés (Seance, Presence, QR), widgets communs
  features/
    auth/      Main, Connexion, Inscription, Profil, chargement / compte en attente
    face/      FaceEmbeddingService (TFLite + factice), FaceCamera (ML Kit), vivacité,
               Visage-Intro / Capture / Enregistré
    student/   Accueil, Emploi du temps, Scan, Selfie, Résultat, Assiduité, Historique
    teacher/   Accueil, Ouvrir la séance, QR dynamique, Présents en direct, Clôture
    director/  Tableau de bord, à risque, décision, audit, règles, gestion, export
supabase/migrations/   SQL à exécuter dans l'ordre
test/                  tests unitaires des règles métier
```

Widgets communs (`lib/core/widgets`) : `AppCard`, `PillButton`, `RoundIconButton`,
`PillField`, `StatusPill`, `StatCard`, `PillBar`, `SessionCard`, `AppBackHeader`,
plus `PillTabs` (puces de filtre) et `AsyncValueView` (chargement / erreur / vide).

## 6. Flux de pointage et sécurité

1. **Enseignant** : `ouvrir_seance` (fenêtre 5/10/15/20 min) → `generer_qr` toutes les 30 s.
   Le QR contient `classcheck:v1:<seance>:<jeton aléatoire 128 bits>`.
2. **Étudiant, étape 1** : `scanner_qr(seance, jeton)` vérifie inscription, ouverture, fenêtre,
   double pointage et validité du jeton (30 s), puis délivre un **ticket de 2 min**.
3. **Étudiant, étape 2** : vivacité (clignement ou sourire, ML Kit) → selfie → embedding
   (192 valeurs) calculé **sur le téléphone** ; la photo est supprimée aussitôt.
   `valider_pointage(ticket, methode, embedding, vivacite)` compare **côté serveur** l'embedding
   aux 5 captures de référence (distance euclidienne, seuil `regles.seuil_visage` = 1.0).
   Ticket à usage unique, 3 essais maximum, contrainte `unique(seance, etudiant)`.
4. **Clôture** : `cloturer_seance` marque les non-pointés `absent` (méthode `auto_cloture`)
   et invalide jetons et tickets.

- **RLS** sur toutes les tables : étudiant → ses données ; enseignant → ses cours et leurs
  étudiants ; directeur → tout. Les étudiants ne voient jamais les jetons QR.
- **Embeddings** : la colonne `face_embedding` n'est lisible par **personne** via l'API (droits
  par colonne) ; seules les fonctions SQL y accèdent. Jamais de photo stockée.
- **Inscription** : un compte enseignant/directeur créé depuis l'application est **inactif**
  jusqu'à activation par le directeur (empêche l'auto-promotion).
- **Audit** : ouverture/clôture de séance, pointages validés et refusés (avec le motif du refus),
  enregistrement du visage, corrections et décisions (trigger, **motif obligatoire**).

## 7. Correspondance avec le scénario de test (Sprint 1)

| Test | Comportement attendu | Code renvoyé |
|---|---|---|
| 4 – cas normal | Présence validée | `ok: true` |
| 5 – QR expiré | Refus, « QR code : Expiré » | `qr_expire` |
| 6 – mauvais visage | Refus, « Visage : Non reconnu » | `visage_non_reconnu` |
| 7 – photo | Bouton bloqué tant que la vivacité n'est pas confirmée ; refus serveur sinon | `vivacite_echouee` |
| 8 – double pointage | Refus au scan, ticket non réutilisable | `deja_pointe`, `ticket_deja_utilise` |
| 9 – hors fenêtre | Refus au scan, plus de QR généré | `hors_fenetre` |
| 10 – séance clôturée | Refus au scan, absents automatiques créés | `seance_cloturee` |
| RLS | Un étudiant ne lit ni les présences d'un autre, ni les jetons, ni les embeddings | 0 ligne / permission refusée |

Ces 8 points ont été vérifiés en exécutant les migrations sur PostgreSQL 16 avec un schéma
`auth` simulé. Les tests côté téléphone restent à faire sur un appareil réel.

## 8. Sprint 2 : parcours

- **Étudiant** : auto-déclaration (retard / absence justifiée), réclamation avec photo du
  justificatif (bucket privé `justificatifs`), suivi (Toutes / En cours / Closes) et recours
  auprès du directeur après un refus, notifications en temps réel (seuil d'absences, décisions).
- **Enseignant** : validation des auto-déclarations, traitement des réclamations (accepter,
  refuser, transmettre), correction manuelle avec motif (toucher un étudiant dans « Présents
  en direct »), statistiques par cours et par étudiant. Les séances oubliées sont clôturées
  automatiquement à l'ouverture de l'accueil.
- **Directeur** : vue d'ensemble filtrable (période, classe, matière), étudiants à risque,
  décision finale sur les litiges, journal d'audit, règles, comptes (activation, rôle, classe,
  création) et emplois du temps, export PDF / CSV (partage Android).

Tests serveur : `supabase/tests/30_scenarios_supabase.sql` s'exécute **dans le SQL Editor
Supabase** et rejoue les tests 4 à 10, la RLS et le circuit réclamation → recours → décision,
puis **annule tout** (le compte rendu s'affiche dans le message « RESULTATS »).

## 9. Tests unitaires

```bash
flutter test
```

- `test/face_math_test.dart` : distance euclidienne, normalisation, distance minimale sur
  5 captures, seuil configurable
- `test/qr_token_test.dart` : validité du jeton (30 s), compte à rebours, décodage du QR
- `test/liveness_test.dart` : clignement, photo fixe refusée, sourire
- `test/widget_test.dart` : formatage, validateurs, lignes des écrans de résultat
- `test/face_precision_test.dart` : alignement du visage, qualité (pose, netteté, éclairage),
  vote sur les captures, dispersion, vivacité par rotation et expiration
- `test/sprint2_test.dart` : statistiques, étudiants à risque, export CSV/PDF, recours, audit
