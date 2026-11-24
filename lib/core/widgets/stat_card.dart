import 'package:flutter/material.dart';

import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/widgets/app_card.dart';

/// Carte de statistique : petit libellé + grande valeur (« Présences 42 »).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.couleur,
    this.hauteur = 96,
    this.onTap,
  });

  final String libelle;
  final String valeur;
  final Color couleur;
  final double hauteur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hauteur,
      child: AppCard(
        couleur: couleur,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(libelle, style: AppText.petit),
            FittedBox(child: Text(valeur, style: AppText.valeur)),
          ],
        ),
      ),
    );
  }
}
