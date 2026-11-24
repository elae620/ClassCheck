import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:classcheck/core/theme/app_colors.dart';

/// Rangée de puces sélectionnables (filtres, rôles, Jour/Semaine…).
class PillTabs<T> extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.options,
    required this.valeur,
    required this.onChanged,
    this.etirer = false,
    this.couleurInactive = AppColors.puce,
  });

  final List<(T, String)> options;
  final T valeur;
  final ValueChanged<T> onChanged;

  /// Si vrai, les puces se partagent toute la largeur (sélecteur de rôle).
  final bool etirer;
  final Color couleurInactive;

  @override
  Widget build(BuildContext context) {
    final puces = [
      for (final (v, libelle) in options)
        _Puce(
          libelle: libelle,
          selectionne: v == valeur,
          couleurInactive: couleurInactive,
          onTap: () => onChanged(v),
        ),
    ];
    if (etirer) {
      return Row(
        children: [
          for (var i = 0; i < puces.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: puces[i]),
          ],
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < puces.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            puces[i],
          ],
        ],
      ),
    );
  }
}

class _Puce extends StatelessWidget {
  const _Puce({
    required this.libelle,
    required this.selectionne,
    required this.couleurInactive,
    required this.onTap,
  });

  final String libelle;
  final bool selectionne;
  final Color couleurInactive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selectionne ? AppColors.texte : couleurInactive,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 34,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            libelle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selectionne ? AppColors.blanc : AppColors.texte,
            ),
          ),
        ),
      ),
    );
  }
}
