import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:classcheck/core/supabase/supabase_providers.dart';
import 'package:classcheck/features/face/data/face_camera.dart';
import 'package:classcheck/features/face/data/face_embedding_service.dart';
import 'package:classcheck/features/face/domain/face_math.dart';

class FaceRepository {
  FaceRepository(this._db);
  final SupabaseClient _db;

  /// Envoie les 5 embeddings (jamais la photo) à la fonction `enregistrer_visage`.
  Future<void> enregistrer(List<List<double>> embeddings) async {
    if (embeddings.length != FaceMath.nbCaptures) {
      throw ArgumentError('nb_captures_invalide');
    }
    // Contrôle local avant l'envoi (le serveur refait le même contrôle).
    if (FaceMath.dispersion(embeddings) > FaceMath.seuilParDefaut * 1.3) {
      throw ArgumentError('captures_incoherentes');
    }
    await _db.rpc('enregistrer_visage', params: {
      'p_embeddings': FaceMath.aplatir(embeddings),
    });
  }
}

final faceRepositoryProvider =
    Provider<FaceRepository>((ref) => FaceRepository(ref.watch(supabaseProvider)));

final faceEmbeddingServiceProvider = FutureProvider<FaceEmbeddingService>((ref) async {
  final service = await FaceEmbeddingService.creer();
  ref.onDispose(service.fermer);
  return service;
});

final faceStillAnalyzerProvider = Provider<FaceStillAnalyzer>((ref) {
  final a = FaceStillAnalyzer();
  ref.onDispose(a.fermer);
  return a;
});

/// Résultat de l'analyse d'une photo : un embedding, ou un code d'erreur.
class AnalysePhoto {
  const AnalysePhoto.ok(this.embedding) : erreur = null;
  const AnalysePhoto.erreur(this.erreur) : embedding = null;
  final List<double>? embedding;
  final String? erreur;
}

/// Photo → détection précise → embedding. Le fichier est supprimé ensuite :
/// aucune photo n'est conservée ni envoyée.
Future<AnalysePhoto> analyserPhoto({
  required String chemin,
  required FaceStillAnalyzer analyseur,
  required FaceEmbeddingService service,
  bool frontal = true,
}) async {
  try {
    final visages = await analyseur.analyser(chemin);
    if (visages.isEmpty) return const AnalysePhoto.erreur('aucun_visage');
    if (visages.length > 1) return const AnalysePhoto.erreur('plusieurs_visages');
    final Face visage = visages.first;
    return AnalysePhoto.ok(await service.calculer(chemin, visage, frontal: frontal));
  } on QualiteVisageException catch (e) {
    // Photo inexploitable (floue, de profil, sombre…) : aucun essai serveur consommé.
    return AnalysePhoto.erreur(e.code);
  } finally {
    try {
      await File(chemin).delete();
    } catch (_) {}
  }
}
