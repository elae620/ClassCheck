import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Caméra frontale + détection de visage en continu (ML Kit, mode rapide).
/// Utilisé par l'enregistrement du visage et par le selfie de pointage.
class FaceCamera extends ChangeNotifier {
  FaceCamera({this.onVisages});

  /// Appelé à chaque image analysée.
  void Function(List<Face> visages)? onVisages;

  final FaceDetector _detecteur = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableClassification: true, // yeux ouverts / sourire → vivacité
      enableTracking: true, // même visage d'une image à l'autre
      minFaceSize: 0.2,
    ),
  );

  CameraController? controleur;
  CameraDescription? _description;
  String? erreur;
  List<Face> visages = const [];
  bool _occupe = false;
  bool _libere = false;
  DateTime _derniere = DateTime.fromMillisecondsSinceEpoch(0);

  bool get prete => controleur?.value.isInitialized ?? false;

  Future<void> initialiser() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', 'Aucune caméra');
      _description = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final c = CameraController(
        _description!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await c.initialize();
      if (_libere) {
        await c.dispose();
        return;
      }
      controleur = c;
      await demarrerAnalyse();
    } on CameraException catch (e) {
      erreur = e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt'
          ? 'Accès à la caméra refusé. Autorisez-le dans les paramètres du téléphone.'
          : 'Caméra indisponible (${e.description ?? e.code}).';
    } catch (e) {
      erreur = 'Caméra indisponible ($e).';
    }
    if (!_libere) notifyListeners();
  }

  Future<void> demarrerAnalyse() async {
    final c = controleur;
    if (c == null || !c.value.isInitialized || c.value.isStreamingImages) return;
    await c.startImageStream(_analyser);
  }

  Future<void> arreterAnalyse() async {
    final c = controleur;
    if (c != null && c.value.isStreamingImages) await c.stopImageStream();
  }

  /// Arrête l'analyse et prend une photo haute qualité (fichier temporaire).
  Future<XFile> photographier() async {
    await arreterAnalyse();
    return controleur!.takePicture();
  }

  Future<void> _analyser(CameraImage image) async {
    final maintenant = DateTime.now();
    if (_occupe || _libere || maintenant.difference(_derniere).inMilliseconds < 120) return;
    _occupe = true;
    _derniere = maintenant;
    try {
      final entree = _versInputImage(image);
      if (entree == null) return;
      final resultat = await _detecteur.processImage(entree);
      if (_libere) return;
      visages = resultat;
      onVisages?.call(resultat);
      notifyListeners();
    } catch (e) {
      debugPrint('Analyse visage : $e');
    } finally {
      _occupe = false;
    }
  }

  InputImage? _versInputImage(CameraImage image) {
    final desc = _description;
    if (desc == null) return null;
    // Application verrouillée en portrait : la rotation = orientation du capteur.
    final rotation = InputImageRotationValue.fromRawValue(desc.sensorOrientation);
    if (rotation == null) return null;
    final taille = Size(image.width.toDouble(), image.height.toDouble());

    if (Platform.isIOS) {
      if (image.planes.length != 1) return null;
      final plan = image.planes.first;
      return InputImage.fromBytes(
        bytes: plan.bytes,
        metadata: InputImageMetadata(
          size: taille,
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plan.bytesPerRow,
        ),
      );
    }

    // Android : NV21 direct, ou conversion depuis YUV_420_888 (3 plans).
    final octets =
        image.planes.length == 1 ? image.planes.first.bytes : _yuv420VersNv21(image);
    return InputImage.fromBytes(
      bytes: octets,
      metadata: InputImageMetadata(
        size: taille,
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      ),
    );
  }

  /// Conversion YUV_420_888 → NV21 (Y puis V/U entrelacés).
  static Uint8List _yuv420VersNv21(CameraImage image) {
    final w = image.width;
    final h = image.height;
    final yPlan = image.planes[0];
    final uPlan = image.planes[1];
    final vPlan = image.planes[2];
    final sortie = Uint8List(w * h + 2 * (w ~/ 2) * (h ~/ 2));
    var i = 0;
    for (var ligne = 0; ligne < h; ligne++) {
      final debut = ligne * yPlan.bytesPerRow;
      sortie.setRange(i, i + w, yPlan.bytes, debut);
      i += w;
    }
    final pasLigne = uPlan.bytesPerRow;
    final pasPixel = uPlan.bytesPerPixel ?? 1;
    for (var ligne = 0; ligne < h ~/ 2; ligne++) {
      for (var col = 0; col < w ~/ 2; col++) {
        final idx = ligne * pasLigne + col * pasPixel;
        if (idx >= vPlan.bytes.length || idx >= uPlan.bytes.length) continue;
        sortie[i++] = vPlan.bytes[idx];
        sortie[i++] = uPlan.bytes[idx];
      }
    }
    return sortie;
  }

  @override
  void dispose() {
    _libere = true;
    final c = controleur;
    controleur = null;
    if (c != null) {
      if (c.value.isStreamingImages) {
        c.stopImageStream().whenComplete(c.dispose);
      } else {
        c.dispose();
      }
    }
    _detecteur.close();
    super.dispose();
  }
}

/// Détecteur précis utilisé sur les photos (repères + contours pour l'embedding).
class FaceStillAnalyzer {
  final FaceDetector _detecteur = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
      enableLandmarks: true,
      enableContours: true,
      minFaceSize: 0.15,
    ),
  );

  Future<List<Face>> analyser(String chemin) =>
      _detecteur.processImage(InputImage.fromFilePath(chemin));

  Future<void> fermer() => _detecteur.close();
}
