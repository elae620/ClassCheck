import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:classcheck/core/theme/app_colors.dart';

/// Petite étiquette de statut (« Présent », « En cours », « 0:18 »…).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.couleur = AppColors.blanc,
    this.couleurTexte = AppColors.texte,
    this.onTap,
  });

  /// Statuts de présence, réutilisés dans tous les écrans.
  factory StatusPill.presence(String statut, {Key? key}) {
    return switch (statut) {
      'present' => StatusPill(key: key, label: 'Présent', couleur: AppColors.menthe),
      'retard' => StatusPill(key: key, label: 'Retard', couleur: AppColors.jaune),
      'absent' => StatusPill(key: key, label: 'Absent', couleur: AppColors.rose),
      _ => StatusPill(key: key, label: 'Attente', couleur: AppColors.jaune),
    };
  }

  final String label;
  final Color couleur;
  final Color couleurTexte;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: couleurTexte,
        ),
      ),
    );
    if (onTap == null) return pill;
    return GestureDetector(onTap: onTap, child: pill);
  }
}
