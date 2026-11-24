import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Presence;

import 'package:classcheck/core/supabase/supabase_providers.dart';
import 'package:classcheck/features/auth/data/auth_repository.dart';
import 'package:classcheck/features/auth/domain/profil.dart';
import 'package:classcheck/features/auth/presentation/chargement_screen.dart';
import 'package:classcheck/features/auth/presentation/connexion_screen.dart';
import 'package:classcheck/features/auth/presentation/inscription_screen.dart';
import 'package:classcheck/features/auth/presentation/main_screen.dart';
import 'package:classcheck/features/auth/presentation/profil_screen.dart';
import 'package:classcheck/core/models/presence.dart';
import 'package:classcheck/features/director/presentation/directeur_tableau_screen.dart';
import 'package:classcheck/features/director/presentation/director_screens.dart';
import 'package:classcheck/features/student/presentation/demandes_screens.dart';
import 'package:classcheck/features/teacher/presentation/suivi_screens.dart';
import 'package:classcheck/features/face/presentation/visage_capture_screen.dart';
import 'package:classcheck/features/face/presentation/visage_enregistre_screen.dart';
import 'package:classcheck/features/face/presentation/visage_intro_screen.dart';
import 'package:classcheck/features/student/domain/pointage.dart';
import 'package:classcheck/features/student/presentation/assiduite_screen.dart';
import 'package:classcheck/features/student/presentation/emploi_temps_screen.dart';
import 'package:classcheck/features/student/presentation/etudiant_accueil_screen.dart';
import 'package:classcheck/features/student/presentation/historique_screen.dart';
import 'package:classcheck/features/student/presentation/pointage_resultat_screen.dart';
import 'package:classcheck/features/student/presentation/scan_screen.dart';
import 'package:classcheck/features/student/presentation/selfie_screen.dart';
import 'package:classcheck/features/teacher/presentation/cloture_screen.dart';
import 'package:classcheck/features/teacher/presentation/enseignant_accueil_screen.dart';
import 'package:classcheck/features/teacher/presentation/ouvrir_seance_screen.dart';
import 'package:classcheck/features/teacher/presentation/presents_screen.dart';
import 'package:classcheck/features/teacher/presentation/qr_seance_screen.dart';

const _routesPubliques = {'/', '/connexion', '/inscription'};

final routerProvider = Provider<GoRouter>((ref) {
  final garde = _GardeNavigation(ref);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: garde,
    redirect: garde.rediriger,
    routes: [
      // --- Communs ---
      GoRoute(path: '/', builder: (_, __) => const MainScreen()),
      GoRoute(path: '/connexion', builder: (_, __) => const ConnexionScreen()),
      GoRoute(path: '/inscription', builder: (_, __) => const InscriptionScreen()),
      GoRoute(path: '/chargement', builder: (_, __) => const ChargementScreen()),
      GoRoute(path: '/attente', builder: (_, __) => const CompteEnAttenteScreen()),
      GoRoute(path: '/profil', builder: (_, __) => const ProfilScreen()),
      GoRoute(path: '/visage/intro', builder: (_, __) => const VisageIntroScreen()),
      GoRoute(path: '/visage/capture', builder: (_, __) => const VisageCaptureScreen()),
      GoRoute(path: '/visage/enregistre', builder: (_, __) => const VisageEnregistreScreen()),

      // --- Étudiant ---
      GoRoute(path: '/etudiant', builder: (_, __) => const EtudiantAccueilScreen()),
      GoRoute(
        path: '/etudiant/emploi',
        builder: (_, __) => const EmploiTempsScreen(role: Role.etudiant),
      ),
      GoRoute(path: '/etudiant/scan', builder: (_, __) => const ScanScreen()),
      GoRoute(
        path: '/etudiant/selfie',
        builder: (_, state) {
          final ticket = state.extra;
          return ticket is TicketPointage ? SelfieScreen(ticket: ticket) : const ScanScreen();
        },
      ),
      GoRoute(
        path: '/etudiant/resultat',
        builder: (_, state) {
          final r = state.extra;
          return r is ResultatPointage
              ? PointageResultatScreen(resultat: r)
              : const EtudiantAccueilScreen();
        },
      ),
      GoRoute(path: '/etudiant/assiduite', builder: (_, __) => const AssiduiteScreen()),
      GoRoute(path: '/etudiant/historique', builder: (_, __) => const HistoriqueScreen()),
      GoRoute(
        path: '/etudiant/auto-declaration',
        builder: (_, s) => AutoDeclarationScreen(seanceId: s.extra is String ? s.extra as String : null),
      ),
      GoRoute(
        path: '/etudiant/reclamation/nouvelle',
        builder: (_, s) => s.extra is Presence
            ? NouvelleReclamationScreen(presence: s.extra as Presence)
            : const MesReclamationsScreen(),
      ),
      GoRoute(path: '/etudiant/reclamations', builder: (_, __) => const MesReclamationsScreen()),
      GoRoute(path: '/etudiant/notifications', builder: (_, __) => const NotificationsScreen()),

      // --- Enseignant ---
      GoRoute(path: '/enseignant', builder: (_, __) => const EnseignantAccueilScreen()),
      GoRoute(
        path: '/enseignant/emploi',
        builder: (_, __) => const EmploiTempsScreen(role: Role.enseignant),
      ),
      GoRoute(
        path: '/enseignant/seance/:id/ouvrir',
        builder: (_, s) => OuvrirSeanceScreen(seanceId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/enseignant/seance/:id/qr',
        builder: (_, s) => QrSeanceScreen(seanceId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/enseignant/seance/:id/presents',
        builder: (_, s) => PresentsScreen(seanceId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/enseignant/seance/:id/cloture',
        builder: (_, s) => ClotureScreen(seanceId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/enseignant/seance/:id/correction/:etudiant',
        builder: (_, s) => CorrectionScreen(
          seanceId: s.pathParameters['id']!,
          etudiantId: s.pathParameters['etudiant']!,
        ),
      ),
      GoRoute(
        path: '/enseignant/auto-declarations',
        builder: (_, __) => const AutoDeclarationsEnseignantScreen(),
      ),
      GoRoute(path: '/enseignant/reclamations', builder: (_, __) => const ReclamationsSuiviScreen()),
      GoRoute(
        path: '/enseignant/reclamation/:id',
        builder: (_, s) => ReclamationDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/enseignant/stats', builder: (_, __) => const StatistiquesScreen()),

      // --- Directeur ---
      GoRoute(path: '/directeur', builder: (_, __) => const DirecteurTableauScreen()),
      GoRoute(path: '/directeur/risque', builder: (_, __) => const EtudiantsARisqueScreen()),
      GoRoute(
        path: '/directeur/reclamations',
        builder: (_, __) => const ReclamationsSuiviScreen(directeur: true),
      ),
      GoRoute(
        path: '/directeur/reclamation/:id',
        builder: (_, s) => ReclamationDetailScreen(id: s.pathParameters['id']!, directeur: true),
      ),
      GoRoute(path: '/directeur/audit', builder: (_, __) => const AuditScreen()),
      GoRoute(path: '/directeur/regles', builder: (_, __) => const ReglesScreen()),
      GoRoute(path: '/directeur/gestion', builder: (_, __) => const GestionScreen()),
      GoRoute(path: '/directeur/export', builder: (_, __) => const ExportScreen()),
    ],
  );
  ref.onDispose(() {
    garde.dispose();
    router.dispose();
  });
  return router;
});

/// Redirections selon la connexion, l'activation du compte, le visage et le rôle.
class _GardeNavigation extends ChangeNotifier {
  _GardeNavigation(this._ref) {
    _ref.listen(currentUserIdProvider, (_, __) => notifyListeners());
    _ref.listen(profilProvider, (_, __) => notifyListeners());
    _ref.listen(authBusyProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? rediriger(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;
    if (_ref.read(authBusyProvider)) return null;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return _routesPubliques.contains(loc) ? null : '/';
    }

    final profilAsync = _ref.read(profilProvider);
    final profil = profilAsync.valueOrNull;
    if (profil == null) {
      // Chargement, erreur ou profil introuvable : écran d'attente dédié.
      return loc == '/chargement' ? null : '/chargement';
    }

    if (!profil.actif) return loc == '/attente' ? null : '/attente';

    if (profil.role == Role.etudiant && !profil.visageEnregistre) {
      return loc.startsWith('/visage') ? null : '/visage/intro';
    }

    final accueil = profil.role.accueil;
    if (_routesPubliques.contains(loc) || loc == '/chargement' || loc == '/attente') {
      return accueil;
    }
    for (final r in Role.values) {
      if (loc.startsWith(r.accueil) && r != profil.role) return accueil;
    }
    return null;
  }
}
