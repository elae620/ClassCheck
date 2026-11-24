import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/widgets/widgets.dart';

/// Écran d'accueil « Pointez en un scan » (maquette Main).
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lavande,
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(child: Center(child: IllustrationQr(taille: 170))),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                child: Column(
                  children: [
                    Text('Pointez en un scan', style: AppText.titre),
                    const SizedBox(height: 10),
                    Text(
                      'QR dynamique et vérification du visage : votre présence est '
                      'enregistrée en quelques secondes.',
                      textAlign: TextAlign.center,
                      style: AppText.secondaire,
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        PillButton(
                          label: 'Commencer',
                          pleineLargeur: false,
                          hauteur: 46,
                          onPressed: () => context.push('/connexion'),
                        ),
                        const Spacer(),
                        RoundIconButton(
                          icone: Icons.arrow_forward,
                          couleur: AppColors.violet,
                          taille: 46,
                          infobulle: 'Créer un compte',
                          onPressed: () => context.push('/inscription'),
                        ),
                      ],
                    ),
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

/// Illustration QR stylisée (blocs bleus + étincelles) des maquettes.
class IllustrationQr extends StatelessWidget {
  const IllustrationQr({super.key, this.taille = 160, this.couleur = AppColors.bleu});

  final double taille;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: taille + 40,
      height: taille + 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(taille), painter: _QrPainter(couleur)),
          const Positioned(
            top: 0,
            left: 4,
            child: Icon(Icons.auto_awesome, color: AppColors.blanc, size: 22),
          ),
          const Positioned(
            top: 14,
            right: 0,
            child: Icon(Icons.auto_awesome, color: AppColors.blanc, size: 18),
          ),
        ],
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.couleur);
  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 20; // grille de 20 unités
    final plein = Paint()..color = couleur;
    final contour = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 1.2;

    void repere(double x, double y) {
      canvas.drawRect(Rect.fromLTWH((x + 0.6) * u, (y + 0.6) * u, 4.8 * u, 4.8 * u), contour);
      canvas.drawRect(Rect.fromLTWH((x + 2) * u, (y + 2) * u, 2 * u, 2 * u), plein);
    }

    repere(0, 0);
    repere(14, 0);
    repere(0, 14);

    const blocs = <List<double>>[
      [8, 1, 2, 2], [11, 3, 2, 1.5], [8, 5, 1.5, 3], [1, 8, 1.5, 4],
      [4, 9, 4, 1.5], [9, 9, 2, 2], [12, 8, 4, 1.5], [17, 10, 2, 2],
      [8, 12, 1.5, 4], [11, 13, 5, 1.5], [14, 16, 1.5, 3], [10, 17, 3, 1.5],
      [17, 15, 2, 4], [5, 12, 2, 1.5],
    ];
    for (final b in blocs) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(b[0] * u, b[1] * u, b[2] * u, b[3] * u),
          Radius.circular(u * 0.2),
        ),
        plein,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) => oldDelegate.couleur != couleur;
}
