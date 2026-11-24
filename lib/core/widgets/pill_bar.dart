import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';

/// Barre de statistique verticale en pilule, fond hachuré
/// (écrans « Mon assiduité » et « Vue d'ensemble »).
class PillBar extends StatelessWidget {
  const PillBar({
    super.key,
    required this.valeur,
    required this.libelle,
    required this.couleur,
    this.sousLibelle,
    this.legende,
    this.hauteur = 130,
    this.largeur = 58,
  });

  /// Remplissage entre 0 et 1.
  final double valeur;
  final String libelle;
  final String? sousLibelle;
  final String? legende;
  final Color couleur;
  final double hauteur;
  final double largeur;

  @override
  Widget build(BuildContext context) {
    final double remplissage = valeur.isNaN ? 0.0 : valeur.clamp(0.25, 1.0).toDouble();
    final radius = BorderRadius.circular(largeur / 2);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: hauteur,
          width: largeur,
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: HachurePainter()),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: remplissage,
                    widthFactor: 1,
                    child: Container(
                      decoration: BoxDecoration(color: couleur, borderRadius: radius),
                      padding: const EdgeInsets.only(top: 14),
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            child: Text(
                              libelle,
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (sousLibelle != null)
                            Text(sousLibelle!, style: AppText.petit.copyWith(fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (legende != null) ...[
          const SizedBox(height: 6),
          Text(legende!, style: AppText.petit),
        ],
      ],
    );
  }
}

/// Fond blanc à rayures diagonales.
class HachurePainter extends CustomPainter {
  const HachurePainter({this.couleur = AppColors.hachure, this.fond = AppColors.blanc});

  final Color couleur;
  final Color fond;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fond);
    final trait = Paint()
      ..color = couleur
      ..strokeWidth = 5;
    const pas = 12.0;
    for (double x = -size.height; x < size.width; x += pas) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), trait);
    }
  }

  @override
  bool shouldRepaint(covariant HachurePainter oldDelegate) =>
      oldDelegate.couleur != couleur || oldDelegate.fond != fond;
}

/// Barre de progression horizontale fine (QR, présents en direct).
class ProgressPill extends StatelessWidget {
  const ProgressPill({
    super.key,
    required this.valeur,
    this.couleur = AppColors.bleu,
    this.fond = AppColors.blanc,
    this.hauteur = 6,
  });

  final double valeur;
  final Color couleur;
  final Color fond;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(hauteur),
      child: LinearProgressIndicator(
        value: valeur.isNaN ? 0.0 : valeur.clamp(0.0, 1.0).toDouble(),
        minHeight: hauteur,
        backgroundColor: fond,
        color: couleur,
      ),
    );
  }
}
