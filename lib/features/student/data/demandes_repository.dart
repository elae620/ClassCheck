import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:classcheck/core/models/sprint2.dart';
import 'package:classcheck/core/supabase/supabase_providers.dart';

/// Demandes de l'étudiant : auto-déclarations, réclamations (avec justificatif
/// dans le bucket privé `justificatifs`) et notifications.
class DemandesRepository {
  DemandesRepository(this._db);
  final SupabaseClient _db;

  static const bucket = 'justificatifs';

  String get _uid => _db.auth.currentUser!.id;

  // ---------------- Auto-déclarations ----------------
  Future<void> autoDeclarer({
    required String seanceId,
    required String type,
    required String motif,
  }) async {
    await _db.from('auto_declarations').insert({
      'seance_id': seanceId,
      'etudiant_id': _uid,
      'type': type,
      'motif': motif.trim(),
    });
  }

  Future<List<AutoDeclaration>> mesAutoDeclarations() async {
    final lignes = await _db
        .from('auto_declarations')
        .select(AutoDeclaration.colonnes)
        .eq('etudiant_id', _uid)
        .order('created_at', ascending: false);
    return lignes.map(AutoDeclaration.fromMap).toList();
  }

  // ---------------- Réclamations ----------------
  /// Envoie le justificatif (photo) puis crée la réclamation.
  /// Le chemin `<uid>/<horodatage>.jpg` est imposé par la politique Storage.
  Future<void> creerReclamation({
    required String presenceId,
    required String motif,
    Uint8List? justificatif,
    String extension = 'jpg',
  }) async {
    String? chemin;
    if (justificatif != null) {
      chemin = '$_uid/${DateTime.now().millisecondsSinceEpoch}.$extension';
      await _db.storage.from(bucket).uploadBinary(
            chemin,
            justificatif,
            fileOptions: FileOptions(contentType: extension == 'png' ? 'image/png' : 'image/jpeg'),
          );
    }
    await _db.from('reclamations').insert({
      'presence_id': presenceId,
      'etudiant_id': _uid,
      'motif': motif.trim(),
      'justificatif_url': chemin,
    });
  }

  Future<List<Reclamation>> mesReclamations() async {
    final lignes = await _db
        .from('reclamations')
        .select(Reclamation.colonnes)
        .eq('etudiant_id', _uid)
        .order('created_at', ascending: false);
    return lignes.map(Reclamation.fromMap).toList();
  }

  /// Recours auprès du directeur après un refus de l'enseignant.
  Future<void> contester(String reclamationId, String motif) async {
    await _db.rpc('contester_reclamation', params: {'p_id': reclamationId, 'p_motif': motif});
  }

  // ---------------- Notifications ----------------
  Stream<List<NotificationApp>> notifications() {
    return _db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('destinataire_id', _uid)
        .order('created_at')
        .map((l) => l.map(NotificationApp.fromMap).toList());
  }

  Future<void> toutMarquerLu() async {
    await _db.from('notifications').update({'lu': true}).eq('destinataire_id', _uid).eq('lu', false);
  }
}

/// URL signée (1 h) d'un justificatif : lisible par l'étudiant, l'enseignant
/// du cours et le directeur (politique Storage).
Future<String> urlJustificatif(SupabaseClient db, String chemin) =>
    db.storage.from(DemandesRepository.bucket).createSignedUrl(chemin, 3600);

final demandesRepositoryProvider =
    Provider<DemandesRepository>((ref) => DemandesRepository(ref.watch(supabaseProvider)));

final mesReclamationsProvider = FutureProvider.autoDispose<List<Reclamation>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(demandesRepositoryProvider).mesReclamations();
});

final mesAutoDeclarationsProvider = FutureProvider.autoDispose<List<AutoDeclaration>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(demandesRepositoryProvider).mesAutoDeclarations();
});

final notificationsProvider = StreamProvider.autoDispose<List<NotificationApp>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(demandesRepositoryProvider).notifications();
});

final nbNonLuesProvider = Provider.autoDispose<int>((ref) =>
    ref.watch(notificationsProvider).valueOrNull?.where((n) => !n.lu).length ?? 0);
