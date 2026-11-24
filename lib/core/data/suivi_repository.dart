import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:classcheck/core/models/sprint2.dart';
import 'package:classcheck/core/supabase/supabase_providers.dart';
import 'package:classcheck/core/utils/formatters.dart';

/// Traitements communs à l'enseignant et au directeur (la RLS et les RPC
/// limitent l'enseignant à ses propres cours) : réclamations,
/// auto-déclarations, corrections et statistiques.
class SuiviRepository {
  SuiviRepository(this._db);
  final SupabaseClient _db;

  Future<List<Reclamation>> reclamations({List<String>? statuts}) async {
    var requete = _db.from('reclamations').select(Reclamation.colonnes);
    if (statuts != null) requete = requete.inFilter('statut', statuts);
    final lignes = await requete.order('created_at', ascending: false);
    return lignes.map(Reclamation.fromMap).toList();
  }

  Future<Reclamation> reclamation(String id) async {
    final l = await _db.from('reclamations').select(Reclamation.colonnes).eq('id', id).single();
    return Reclamation.fromMap(l);
  }

  /// [decision] : acceptee | refusee | transmise. Commentaire obligatoire (audit).
  Future<void> traiterReclamation(String id, String decision, String commentaire) async {
    await _db.rpc('traiter_reclamation', params: {
      'p_id': id,
      'p_decision': decision,
      'p_commentaire': commentaire,
    });
  }

  Future<List<AutoDeclaration>> autoDeclarationsEnAttente() async {
    final lignes = await _db
        .from('auto_declarations')
        .select(AutoDeclaration.colonnes)
        .eq('statut', 'en_attente')
        .order('created_at', ascending: false);
    return lignes.map(AutoDeclaration.fromMap).toList();
  }

  Future<void> traiterAutoDeclaration(String id, {required bool valider, String? motif}) async {
    await _db.rpc('traiter_auto_declaration', params: {
      'p_id': id,
      'p_valider': valider,
      'p_motif': motif,
    });
  }

  Future<void> corrigerPresence({
    required String seanceId,
    required String etudiantId,
    required String statut,
    required String motif,
  }) async {
    await _db.rpc('corriger_presence', params: {
      'p_seance_id': seanceId,
      'p_etudiant_id': etudiantId,
      'p_statut': statut,
      'p_motif': motif,
    });
  }

  Future<StatsPresences> stats(FiltreStats f) async {
    final r = await _db.rpc('stats_presences', params: {
      'p_debut': f.debut == null ? null : Fmt.dateSql(f.debut!),
      'p_fin': f.fin == null ? null : Fmt.dateSql(f.fin!),
      'p_classe': f.classe,
      'p_cours_id': f.coursId,
    });
    return StatsPresences.fromMap((r as Map).cast<String, dynamic>());
  }

  Future<List<EtudiantARisque>> etudiantsARisque() async {
    final r = await _db.rpc('etudiants_a_risque');
    return [for (final l in (r as List)) EtudiantARisque.fromMap((l as Map).cast<String, dynamic>())];
  }

  /// Clôture les séances passées que l'enseignant a oublié de clôturer.
  Future<int> cloturerSeancesPassees() async {
    final r = await _db.rpc('cloturer_seances_passees');
    return (r as num?)?.toInt() ?? 0;
  }
}

/// Filtre des statistiques (période, classe, cours).
class FiltreStats {
  const FiltreStats({this.debut, this.fin, this.classe, this.coursId});
  final DateTime? debut;
  final DateTime? fin;
  final String? classe;
  final String? coursId;

  @override
  bool operator ==(Object other) =>
      other is FiltreStats &&
      other.debut == debut &&
      other.fin == fin &&
      other.classe == classe &&
      other.coursId == coursId;

  @override
  int get hashCode => Object.hash(debut, fin, classe, coursId);
}

final suiviRepositoryProvider =
    Provider<SuiviRepository>((ref) => SuiviRepository(ref.watch(supabaseProvider)));

final statsProvider = FutureProvider.autoDispose.family<StatsPresences, FiltreStats>(
  (ref, f) => ref.watch(suiviRepositoryProvider).stats(f),
);

final reclamationsProvider =
    FutureProvider.autoDispose.family<List<Reclamation>, String?>((ref, statut) {
  ref.watch(currentUserIdProvider);
  return ref
      .watch(suiviRepositoryProvider)
      .reclamations(statuts: statut == null ? null : [statut]);
});

final reclamationProvider = FutureProvider.autoDispose.family<Reclamation, String>(
  (ref, id) => ref.watch(suiviRepositoryProvider).reclamation(id),
);

final autoDeclarationsEnAttenteProvider = FutureProvider.autoDispose<List<AutoDeclaration>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(suiviRepositoryProvider).autoDeclarationsEnAttente();
});

final etudiantsARisqueProvider = FutureProvider.autoDispose<List<EtudiantARisque>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(suiviRepositoryProvider).etudiantsARisque();
});
