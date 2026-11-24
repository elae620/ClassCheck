import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/messages_erreur.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/auth/data/auth_repository.dart';
import 'package:classcheck/features/face/data/face_camera.dart';
import 'package:classcheck/features/face/data/face_repository.dart';
import 'package:classcheck/features/face/domain/face_math.dart';
import 'package:classcheck/features/face/presentation/widgets/face_oval.dart';

/// Maquette « Visage-Capture » : 5 captures automatiques sous différents angles.
class VisageCaptureScreen extends ConsumerStatefulWidget {
  const VisageCaptureScreen({super.key});

  @override
  ConsumerState<VisageCaptureScreen> createState() => _VisageCaptureScreenState();
}

class _VisageCaptureScreenState extends ConsumerState<VisageCaptureScreen> {
  static const _consignes = [
    'Regardez droit devant',
    'Tournez légèrement à gauche',
    'Tournez légèrement à droite',
    'Levez légèrement le menton',
    'Regardez à nouveau droit devant',
  ];

  late final FaceCamera _camera = FaceCamera(onVisages: _surVisages);
  final List<List<double>> _embeddings = [];
  DateTime? _stableDepuis;
  bool _capture = false;
  double? _signeGauche;
  String? _message;

  int get _etape => _embeddings.length;

  @override
  void initState() {
    super.initState();
    _camera.addListener(_rafraichir);
    _camera.initialiser();
  }

  void _rafraichir() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _camera.removeListener(_rafraichir);
    _camera.dispose();
    super.dispose();
  }

  /// Le visage respecte-t-il la consigne de l'étape courante ?
  bool _respecteConsigne(Face v) {
    final y = v.headEulerAngleY ?? 0; // rotation gauche/droite
    final x = v.headEulerAngleX ?? 0; // haut/bas
    switch (_etape) {
      case 1:
        return y.abs() >= 10 && y.abs() <= 40;
      case 2:
        // côté opposé à la capture précédente
        return y.abs() >= 10 && y.abs() <= 40 && (_signeGauche == null || y.sign != _signeGauche);
      case 3:
        return x >= 8 && x <= 35;
      default:
        return y.abs() < 10 && x.abs() < 12;
    }
  }

  void _surVisages(List<Face> visages) {
    if (_capture || _etape >= FaceMath.nbCaptures) return;
    if (visages.length != 1) {
      _stableDepuis = null;
      _message = visages.isEmpty ? 'Aucun visage détecté' : 'Un seul visage dans le cadre';
      return;
    }
    _message = null;
    if (!_respecteConsigne(visages.first)) {
      _stableDepuis = null;
      return;
    }
    _stableDepuis ??= DateTime.now();
    if (DateTime.now().difference(_stableDepuis!).inMilliseconds >= 600) {
      _capturer(visages.first.headEulerAngleY ?? 0);
    }
  }

  Future<void> _capturer(double angleY) async {
    _capture = true;
    _stableDepuis = null;
    try {
      final service = await ref.read(faceEmbeddingServiceProvider.future);
      final photo = await _camera.photographier();
      final analyse = await analyserPhoto(
        chemin: photo.path,
        analyseur: ref.read(faceStillAnalyzerProvider),
        service: service,
        // Les captures de côté (étapes 2 à 4) tolèrent une pose de trois quarts.
        frontal: _etape == 0 || _etape == FaceMath.nbCaptures - 1,
      );
      if (analyse.embedding == null) {
        _message = libellesCodes[analyse.erreur] ?? 'Capture impossible, réessayez.';
      } else {
        if (_etape == 1) _signeGauche = angleY.sign;
        _embeddings.add(analyse.embedding!);
      }
      if (_etape >= FaceMath.nbCaptures) {
        await _enregistrer();
        return;
      }
      await _camera.demarrerAnalyse();
    } catch (e) {
      _message = messageErreur(e);
      await _camera.demarrerAnalyse();
    } finally {
      _capture = false;
      _rafraichir();
    }
  }

  Future<void> _enregistrer() async {
    try {
      await ref.read(faceRepositoryProvider).enregistrer(_embeddings);
      ref.invalidate(profilProvider);
      if (mounted) context.go('/visage/enregistre');
    } catch (e) {
      _embeddings.clear();
      _message = '${messageErreur(e)} Recommencez.';
      await _camera.demarrerAnalyse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(faceEmbeddingServiceProvider);
    final detecte = _camera.visages.length == 1;
    final fini = _etape >= FaceMath.nbCaptures;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Enregistrer mon visage', repli: '/visage/intro'),
            Expanded(
              child: _camera.erreur != null
                  ? VueErreur(message: _camera.erreur!)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        children: [
                          StatusPill(
                            label: detecte ? 'Visage détecté' : 'Aucun visage',
                            couleur: detecte ? AppColors.menthe : AppColors.jaune,
                          ),
                          const SizedBox(height: 12),
                          FaceOval(
                            camera: _camera,
                            couleurBordure: detecte ? AppColors.bleu : AppColors.violet,
                          ),
                          const SizedBox(height: 18),
                          AppCard(
                            couleur: AppColors.lavande,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        fini
                                            ? 'Enregistrement…'
                                            : _consignes[_etape],
                                        style: AppText.sousTitre,
                                      ),
                                    ),
                                    StatusPill(
                                      label: '${fini ? FaceMath.nbCaptures : _etape + 1}/${FaceMath.nbCaptures}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    for (var i = 0; i < FaceMath.nbCaptures; i++) ...[
                                      if (i > 0) const SizedBox(width: 6),
                                      Expanded(
                                        child: Container(
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: i < _etape ? AppColors.bleu : AppColors.blanc,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _message ?? 'La capture se fait automatiquement',
                            style: AppText.petit,
                            textAlign: TextAlign.center,
                          ),
                          if (service.valueOrNull?.estFactice ?? false) ...[
                            const SizedBox(height: 10),
                            const StatusPill(
                              label: 'Mode démo : modèle visage absent',
                              couleur: AppColors.jaune,
                            ),
                          ],
                          if (_capture || fini) ...[
                            const SizedBox(height: 12),
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
