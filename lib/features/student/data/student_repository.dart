import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Presence;

import 'package:classcheck/core/models/presence.dart';
import 'package:classcheck/core/models/seance.dart';
import 'package:classcheck/core/supabase/supabase_providers.dart';

/// Compteur « 24 présents sur 30 ».
class Compteur {
  const Compteur(this.presents, this.total);
  final int presents;
  final int total;
}

/// Réponse brute d'une RPC de pointage : {ok, erreur, ...}.
class ReponsePointage {
  const ReponsePointage(this.donnees);
  final Map<String, dynamic> donnees;
  bool get ok => donnees['ok'] == true;
  String? get erreur => donnees['erreur'] as String?;
}

class StudentRepository {
  StudentRepository(this._db);
  final SupabaseClient _db;

  String get _uid => _db.auth.currentUser!.id;

  Future<List<Presence>> mesPresences() async {
    final lignes = await _db
        .from('presences')
        .select('id, seance_id, etudiant_id, statut, methode, pointe_a, justifiee, '
            'seance:seance_id(${Seance.colonnes})')
        .eq('etudiant_id', _uid);
    final liste = lignes.map(Presence.fromMap).toList();
    // Plus récentes d'abord.
    liste.sort((a, b) {
      final da = a.seance?.debut ?? a.pointeA ?? DateTime(2000);
      final db = b.seance?.debut ?? b.pointeA ?? DateTime(2000);
      return db.compareTo(da);
    });
    return liste;
  }

  Future<Compteur> compteur(String seanceId) async {
    final r = await _db.rpc('compteur_seance', params: {'p_seance_id': seanceId});
    final m = (r as Map).cast<String, dynamic>();
    return Compteur((m['presents'] ?? 0) as int, (m['total'] ?? 0) as int);
  }

  /// Étape 1 : vérifie le QR (30 s) et obtient un ticket (2 min).
  Future<ReponsePointage> scannerQr(String seanceId, String token) async {
    final r = await _db.rpc('scanner_qr', params: {
      'p_seance_id': seanceId,
      'p_token': token,
    });
    return ReponsePointage((r as Map).cast<String, dynamic>());
  }

  /// Étape 2 : valide la présence (embedding du selfie + vivacité).
  Future<ReponsePointage> validerPointage({
    required String ticketId,
    required String methode,
    List<double>? embedding,
    bool vivacite = false,
  }) async {
    final r = await _db.rpc('valider_pointage', params: {
      'p_ticket_id': ticketId,
      'p_methode': methode,
      'p_embedding': embedding,
      'p_vivacite': vivacite,
    });
    return ReponsePointage((r as Map).cast<String, dynamic>());
  }
}

final studentRepositoryProvider =
    Provider<StudentRepository>((ref) => StudentRepository(ref.watch(supabaseProvider)));

final mesPresencesProvider = FutureProvider.autoDispose<List<Presence>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(studentRepositoryProvider).mesPresences();
});

final compteurSeanceProvider = FutureProvider.autoDispose.family<Compteur, String>(
  (ref, id) => ref.watch(studentRepositoryProvider).compteur(id),
);

/// Statistiques d'assiduité calculées à partir des présences.
class Assiduite {
  const Assiduite(this.presences);
  final List<Presence> presences;

  int get nbPresents => presences.where((p) => p.statut == 'present').length;
  int get nbRetards => presences.where((p) => p.statut == 'retard').length;
  int get nbAbsences => presences.where((p) => p.statut == 'absent').length;

  /// Taux d'assiduité : (présents + retards) / total.
  double get taux =>
      presences.isEmpty ? 1.0 : (nbPresents + nbRetards) / presences.length;

  int get tauxPourcent => (taux * 100).round();

  /// Taux par mois (clé : année*100 + mois), pour les barres de progression.
  Map<int, double> parMois() {
    final groupes = <int, List<Presence>>{};
    for (final p in presences) {
      final d = p.seance?.date ?? p.pointeA;
      if (d == null) continue;
      groupes.putIfAbsent(d.year * 100 + d.month, () => []).add(p);
    }
    return {for (final e in groupes.entries) e.key: Assiduite(e.value).taux};
  }
}
