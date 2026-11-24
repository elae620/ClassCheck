import 'package:flutter/material.dart';

import 'package:classcheck/core/theme/app_colors.dart';

/// Carte arrondie (rayon 28) utilisée partout dans les maquettes.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.couleur = AppColors.blanc,
    this.padding = const EdgeInsets.all(16),
    this.rayon = 28,
    this.onTap,
    this.bordure,
  });

  final Widget child;
  final Color couleur;
  final EdgeInsetsGeometry padding;
  final double rayon;
  final VoidCallback? onTap;
  final BoxBorder? bordure;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(rayon);
    return Material(
      color: couleur,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          decoration: bordure == null
              ? null
              : BoxDecoration(borderRadius: radius, border: bordure),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
