import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:classcheck/features/face/domain/face_alignment.dart';
import 'package:classcheck/features/face/domain/face_math.dart';
import 'package:classcheck/features/face/domain/face_quality.dart';

/// Photo refusée par les contrôles de qualité (code traduit par `libellesCodes`).
class QualiteVisageException implements Exception {
  const QualiteVisageException(this.code);
  final String code;
  @override
  String toString() => code;
}

/// Transforme un visage (photo + détection ML Kit) en embedding de 192
/// valeurs normalisé. Toute la logique ML est isolée ici.
abstract class FaceEmbeddingService {
  /// Vrai si le modèle `.tflite` est absent et qu'on utilise l'implémentation factice.
  bool get estFactice;

  /// [frontal] : photo de vérification (pose de face exigée). Les captures
  /// d'enregistrement de côté passent `frontal: false`.
  /// Lève [QualiteVisageException] si la photo n'est pas exploitable.
  Future<List<double>> calculer(String cheminImage, Face visage, {bool frontal = true});

  Future<void> fermer();

  /// Charge le modèle TFLite ; à défaut, renvoie l'implémentation factice.
  static Future<FaceEmbeddingService> creer() async {
    try {
      final options = InterpreterOptions()..threads = 2;
      final interpreteur =
          await Interpreter.fromAsset(TfliteFaceEmbeddingService.cheminModele, options: options);
      return TfliteFaceEmbeddingService(interpreteur);
    } catch (e) {
      debugPrint('Modèle visage absent ($e) : implémentation factice utilisée.');
      return FakeFaceEmbeddingService();
    }
  }
}

/// Contrôle de pose commun aux deux implémentations.
void _verifierPose(Face visage, {required bool frontal}) {
  final code = FaceQuality.verifierPose(
    largeurVisage: visage.boundingBox.width,
    lacet: visage.headEulerAngleY,
    tangage: visage.headEulerAngleX,
    roulis: visage.headEulerAngleZ,
    oeilGauche: visage.leftEyeOpenProbability,
    oeilDroit: visage.rightEyeOpenProbability,
    frontal: frontal,
  );
  if (code != null) throw QualiteVisageException(code);
}

/// Implémentation réelle : MobileFaceNet (entrée 112×112×3, sortie 192).
///
/// Précision améliorée par rapport à un simple recadrage :
///  1. contrôle de qualité (pose, taille, yeux ouverts, netteté, éclairage) ;
///  2. alignement sur les yeux (comme les visages d'entraînement du modèle) ;
///  3. moyenne des embeddings de l'image et de son miroir (« test-time
///     augmentation ») : réduit la sensibilité à l'éclairage latéral et au
///     sens de la caméra frontale ;
///  4. normalisation L2 (distances entre 0 et 2, seuil 1.0).
class TfliteFaceEmbeddingService implements FaceEmbeddingService {
  TfliteFaceEmbeddingService(this._interpreteur) {
    final entree = _interpreteur.getInputTensor(0).shape; // [1, 112, 112, 3]
    final sortie = _interpreteur.getOutputTensor(0).shape; // [1, 192]
    _taille = entree[1];
    _dimSortie = sortie.last;
    if (_dimSortie != FaceMath.dimension) {
      throw StateError('Le modèle produit $_dimSortie valeurs au lieu de ${FaceMath.dimension}');
    }
  }

  static const cheminModele = 'assets/models/mobilefacenet.tflite';

  final Interpreter _interpreteur;
  late final int _taille;
  late final int _dimSortie;

  @override
  bool get estFactice => false;

  @override
  Future<List<double>> calculer(String cheminImage, Face visage, {bool frontal = true}) async {
    _verifierPose(visage, frontal: frontal);

    final octets = await File(cheminImage).readAsBytes();
    final decode = img.decodeImage(octets);
    if (decode == null) throw StateError('Image illisible');
    // Même orientation que celle utilisée par ML Kit (EXIF appliqué).
    final image = img.bakeOrientation(decode);

    final gauche = visage.landmarks[FaceLandmarkType.leftEye]?.position;
    final droit = visage.landmarks[FaceLandmarkType.rightEye]?.position;
    final cadre = visage.boundingBox;
    final VisageAligne aligne = (gauche != null && droit != null)
        ? FaceAligner.aligner(
            image,
            math.Point(gauche.x.toDouble(), gauche.y.toDouble()),
            math.Point(droit.x.toDouble(), droit.y.toDouble()),
            taille: _taille,
          )
        : FaceAligner.recadrer(image,
            gauche: cadre.left,
            haut: cadre.top,
            largeur: cadre.width,
            hauteur: cadre.height,
            taille: _taille);

    final qualite = FaceQuality.verifierImage(aligne.gris, aligne.taille, aligne.taille);
    if (qualite != null) throw QualiteVisageException(qualite);

    final a = _executer(aligne.rgb);
    final b = _executer(aligne.rgbMiroir);
    return FaceMath.normaliser([
      for (var i = 0; i < a.length; i++) a[i] + b[i],
    ]);
  }

  List<double> _executer(Float32List pixels) {
    final entree = pixels.reshape([1, _taille, _taille, 3]);
    final sortie = [List<double>.filled(_dimSortie, 0)];
    _interpreteur.run(entree, sortie);
    // Chaque passage est normalisé avant la moyenne (poids égal image / miroir).
    return FaceMath.normaliser(sortie.first);
  }

  @override
  Future<void> fermer() async => _interpreteur.close();
}

/// Implémentation FACTICE (développement uniquement) : vecteur construit à
/// partir de la géométrie du visage (contours et repères ML Kit).
/// Elle ne distingue pas fiablement deux personnes.
class FakeFaceEmbeddingService implements FaceEmbeddingService {
  @override
  bool get estFactice => true;

  @override
  Future<List<double>> calculer(String cheminImage, Face visage, {bool frontal = true}) async {
    _verifierPose(visage, frontal: frontal);
    final cadre = visage.boundingBox;
    final w = cadre.width == 0 ? 1.0 : cadre.width;
    final h = cadre.height == 0 ? 1.0 : cadre.height;
    final traits = <double>[];
    for (final type in FaceContourType.values) {
      for (final pt in visage.contours[type]?.points ?? const <math.Point<int>>[]) {
        traits
          ..add((pt.x - cadre.left) / w - 0.5)
          ..add((pt.y - cadre.top) / h - 0.5);
      }
    }
    for (final type in FaceLandmarkType.values) {
      final pos = visage.landmarks[type]?.position;
      if (pos != null) {
        traits
          ..add((pos.x - cadre.left) / w - 0.5)
          ..add((pos.y - cadre.top) / h - 0.5);
      }
    }
    if (traits.isEmpty) traits.addAll([cadre.width / (cadre.height + 1), 0.5]);
    final v = List<double>.generate(
      FaceMath.dimension,
      (i) => traits[i % traits.length] * (1 + (i ~/ traits.length) * 0.05),
    );
    return FaceMath.normaliser(v);
  }

  @override
  Future<void> fermer() async {}
}
