import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:classcheck/core/theme/app_colors.dart';

enum PillVariant { sombre, clair, violet }

/// Bouton pilule (hauteur 52 par défaut).
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PillVariant.sombre,
    this.chargement = false,
    this.pleineLargeur = true,
    this.hauteur = 52,
    this.icone,
  });

  /// Petit bouton utilisé dans les cartes (« Pointer », « Réclamer »…).
  const PillButton.petit({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PillVariant.sombre,
    this.chargement = false,
    this.icone,
  })  : pleineLargeur = false,
        hauteur = 34;

  final String label;
  final VoidCallback? onPressed;
  final PillVariant variant;
  final bool chargement;
  final bool pleineLargeur;
  final double hauteur;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final (fond, texte) = switch (variant) {
      PillVariant.sombre => (AppColors.texte, AppColors.blanc),
      PillVariant.clair => (AppColors.blanc, AppColors.texte),
      PillVariant.violet => (AppColors.violet, AppColors.texte),
    };
    final petit = hauteur < 40;
    final bouton = SizedBox(
      height: hauteur,
      width: pleineLargeur ? double.infinity : null,
      child: ElevatedButton(
        onPressed: chargement ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: fond,
          foregroundColor: texte,
          disabledBackgroundColor: fond.withValues(alpha: 0.45),
          disabledForegroundColor: texte.withValues(alpha: 0.8),
          shape: const StadiumBorder(),
          padding: EdgeInsets.symmetric(horizontal: petit ? 16 : 24),
          textStyle: GoogleFonts.poppins(
            fontSize: petit ? 11 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: chargement
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: texte),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icone != null) ...[
                    Icon(icone, size: petit ? 14 : 18),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(label, textAlign: TextAlign.center, maxLines: 2),
                  ),
                ],
              ),
      ),
    );
    return bouton;
  }
}
