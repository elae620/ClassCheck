import 'package:flutter/material.dart';

import 'package:classcheck/core/theme/app_colors.dart';

/// Bouton icône rond (diamètre 44 par défaut).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icone,
    required this.onPressed,
    this.couleur = AppColors.blanc,
    this.couleurIcone = AppColors.texte,
    this.taille = 44,
    this.infobulle,
  });

  final IconData icone;
  final VoidCallback? onPressed;
  final Color couleur;
  final Color couleurIcone;
  final double taille;
  final String? infobulle;

  @override
  Widget build(BuildContext context) {
    final bouton = Material(
      color: couleur,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: taille,
          height: taille,
          child: Icon(icone, size: taille * 0.45, color: couleurIcone),
        ),
      ),
    );
    if (infobulle == null) return bouton;
    return Tooltip(message: infobulle!, child: bouton);
  }
}
