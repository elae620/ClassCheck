import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/features/face/data/face_camera.dart';

/// Cadre ovale des maquettes « visage » : aperçu caméra ou silhouette.
class FaceOval extends StatelessWidget {
  const FaceOval({
    super.key,
    this.camera,
    this.couleurBordure = AppColors.violet,
    this.largeur = 220,
    this.hauteur = 280,
  });

  final FaceCamera? camera;
  final Color couleurBordure;
  final double largeur;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    final c = camera?.controleur;
    final apercu = (c != null && c.value.isInitialized && c.value.previewSize != null)
        ? FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              // previewSize est exprimée en paysage : on inverse pour le portrait.
              width: c.value.previewSize!.height,
              height: c.value.previewSize!.width,
              child: CameraPreview(c),
            ),
          )
        : const _Silhouette();
    return Container(
      width: largeur,
      height: hauteur,
      decoration: ShapeDecoration(
        shape: OvalBorder(side: BorderSide(color: couleurBordure, width: 3)),
      ),
      padding: const EdgeInsets.all(3),
      child: ClipOval(child: apercu),
    );
  }
}

class _Silhouette extends StatelessWidget {
  const _Silhouette();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lavande,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          final couleur = AppColors.violet.withValues(alpha: 0.9);
          return Stack(
            children: [
              Positioned(
                left: w * 0.33,
                top: h * 0.33,
                width: w * 0.34,
                height: w * 0.34,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
                ),
              ),
              Positioned(
                left: w * 0.22,
                top: h * 0.62,
                width: w * 0.56,
                height: h * 0.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: couleur,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(w * 0.3)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
