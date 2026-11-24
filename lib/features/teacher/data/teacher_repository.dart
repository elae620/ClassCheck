import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Presence;

import 'package:classcheck/core/models/presence.dart';
import 'package:classcheck/core/models/qr_seance.dart';
import 'package:classcheck/core/supabase/supabase_providers.dart';

/// Étudiant d'une classe (lecture limitée par la RLS aux classes de l'enseignant).
class EtudiantResume {
  const EtudiantResume(this.id, this.nom);
  final String id;
  final String nom;
}

class TeacherRepository {
  TeacherRepository(this._db);
  final SupabaseClient _db;

  Future<void> ouvrirSeance(String seanceId, {required int fenetre, required bool visage}) async {
    await _db.rpc('ouvrir_seance', params: {
      'p_seance_id': seanceId,
      'p_fenetre': fenetre,
      'p_visage': visage,
    });
  }

  Future<QrToken> genererQr(String seanceId) async {
    final r = await _db.rpc('generer_qr', params: {'p_seance_id': seanceId});
    return QrToken.fromMap((r as Map).cast<String, dynamic>());
  }

  Future<Map<String, dynamic>> cloturer(String seanceId) async {
    final r = await _db.rpc('cloturer_seance', params: {'p_seance_id': seanceId});
    return (r as Map).cast<String, dynamic>();
  }

  Future<List<EtudiantResume>> etudiantsDeClasse(String classe) async {
    final lignes = await _db
        .from('profils')
        .select('id, nom')
        .eq('role', 'etudiant')
        .eq('classe', classe)
        .eq('actif', true)
        .order('nom');
    return [for (final l in lignes) EtudiantResume(l['id'] as String, l['nom'] as String)];
  }

  /// Présences d'une séance en temps réel (Supabase Realtime, filtré par la RLS).
  Stream<List<Presence>> presencesEnDirect(String seanceId) {
    return _db
        .from('presences')
        .stream(primaryKey: ['id'])
        .eq('seance_id', seanceId)
        .map((lignes) => lignes.map(Presence.fromMap).toList());
  }
}

final teacherRepositoryProvider =
    Provider<TeacherRepository>((ref) => TeacherRepository(ref.watch(supabaseProvider)));

final etudiantsClasseProvider = FutureProvider.autoDispose.family<List<EtudiantResume>, String>(
  (ref, classe) => ref.watch(teacherRepositoryProvider).etudiantsDeClasse(classe),
);

final presencesEnDirectProvider = StreamProvider.autoDispose.family<List<Presence>, String>(
  (ref, seanceId) => ref.watch(teacherRepositoryProvider).presencesEnDirect(seanceId),
);
