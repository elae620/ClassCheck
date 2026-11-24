import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:classcheck/core/data/seance_repository.dart';
import 'package:classcheck/core/models/sprint2.dart';
import 'package:classcheck/core/supabase/supabase_providers.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/features/auth/domain/profil.dart';

/// Cours (gestion des emplois du temps).
class Cours {
  const Cours({
    required this.id,
    required this.nom,
    required this.nomCourt,
    required this.classe,
    this.salle,
    this.enseignantId,
    this.enseignantNom,
  });

  final String id;
  final String nom;
  final String nomCourt;
  final String classe;
  final String? salle;
  final String? enseignantId;
  final String? enseignantNom;

  factory Cours.fromMap(Map<String, dynamic> m) => Cours(
        id: m['id'] as String,
        nom: m['nom'] as String,
        nomCourt: (m['nom_court'] ?? m['nom']) as String,
        classe: m['classe'] as String,
        salle: m['salle'] as String?,
        enseignantId: m['enseignant_id'] as String?,
        enseignantNom: (m['enseignant'] as Map?)?['nom'] as String?,
      );
}

/// Fonctions réservées au directeur (contrôlées côté serveur par `est_directeur()`).
class DirectorRepository {
  DirectorRepository(this._db);
  final SupabaseClient _db;

  Future<List<EntreeAudit>> audit({int limite = 200}) async {
    final lignes = await _db
        .from('audit_log')
        .select('id, action, details, motif, created_at, acteur:acteur_id(nom)')
        .order('created_at', ascending: false)
        .limit(limite);
    return lignes.map(EntreeAudit.fromMap).toList();
  }

  Future<void> enregistrerRegles(Regles r, {String? motif}) async {
    await _db.from('regles').update({
      'seuil_exclusion': r.seuilExclusion,
      'fenetre_pointage': r.fenetrePointage,
      'renouvellement_qr': r.renouvellementQr,
      'visage_obligatoire': r.visageObligatoire,
      'seuil_visage': r.seuilVisage,
      'votes_visage': r.votesVisage,
    }).eq('id', 1);
  }

  Future<List<Profil>> comptes() async {
    final lignes = await _db.from('profils').select(Profil.colonnes).order('role').order('nom');
    return lignes.map(Profil.fromMap).toList();
  }

  Future<void> gererCompte(String id,
      {required Role role, String? classe, required bool actif, String? motif}) async {
    await _db.rpc('gerer_compte', params: {
      'p_id': id,
      'p_role': role.valeur,
      'p_classe': classe,
      'p_actif': actif,
      'p_motif': motif,
    });
  }

  Future<void> creerCompte({
    required String email,
    required String nom,
    required Role role,
    String? classe,
    required String motDePasse,
  }) async {
    await _db.rpc('creer_compte', params: {
      'p_email': email,
      'p_nom': nom,
      'p_role': role.valeur,
      'p_classe': classe,
      'p_mot_de_passe': motDePasse,
    });
  }

  Future<List<Cours>> cours() async {
    final lignes = await _db
        .from('cours')
        .select('id, nom, nom_court, classe, salle, enseignant_id, enseignant:enseignant_id(nom)')
        .order('classe')
        .order('nom');
    return lignes.map(Cours.fromMap).toList();
  }

  Future<void> creerCours({
    required String nom,
    required String nomCourt,
    required String classe,
    String? salle,
    String? enseignantId,
  }) async {
    await _db.from('cours').insert({
      'nom': nom.trim(),
      'nom_court': nomCourt.trim().isEmpty ? null : nomCourt.trim(),
      'classe': classe,
      'salle': salle,
      'enseignant_id': enseignantId,
    });
  }

  /// Crée une séance par semaine pendant [semaines] semaines.
  Future<int> planifierSeances({
    required String coursId,
    required DateTime premiere,
    required String heureDebut,
    required String heureFin,
    String? salle,
    int semaines = 1,
  }) async {
    final r = await _db.rpc('planifier_seances', params: {
      'p_cours_id': coursId,
      'p_premiere': Fmt.dateSql(premiere),
      'p_heure_debut': heureDebut,
      'p_heure_fin': heureFin,
      'p_salle': salle,
      'p_semaines': semaines,
    });
    return (r as num?)?.toInt() ?? 0;
  }
}

final directorRepositoryProvider =
    Provider<DirectorRepository>((ref) => DirectorRepository(ref.watch(supabaseProvider)));

final auditProvider = FutureProvider.autoDispose<List<EntreeAudit>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(directorRepositoryProvider).audit();
});

final comptesProvider = FutureProvider.autoDispose<List<Profil>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(directorRepositoryProvider).comptes();
});

final coursProvider = FutureProvider.autoDispose<List<Cours>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(directorRepositoryProvider).cours();
});
