import 'package:flutter/material.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/widgets/status_pill.dart';

/// Indicateur « 1 · QR   2 · Selfie   3 · Validé ».
class EtapesPointage extends StatelessWidget {
  const EtapesPointage({super.key, required this.etape});

  /// 0 = QR, 1 = Selfie, 2 = Validé
  final int etape;

  static const _libelles = ['1 · QR', '2 · Selfie', '3 · Validé'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < _libelles.length; i++)
          StatusPill(
            label: _libelles[i],
            couleur: i == etape ? AppColors.texte : Colors.transparent,
            couleurTexte: i == etape ? AppColors.blanc : AppColors.texte,
          ),
      ],
    );
  }
}
