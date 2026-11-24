import 'package:flutter/material.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/widgets/app_card.dart';
import 'package:classcheck/core/widgets/round_icon_button.dart';
import 'package:classcheck/core/widgets/status_pill.dart';

/// Carte de séance de l'accueil étudiant (« En cours », « À venir »).
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.etat,
    required this.plage,
    required this.titre,
    required this.sousTitre,
    required this.couleur,
    this.pied,
    this.onFleche,
    this.onTap,
  });

  final String etat;
  final String plage;
  final String titre;
  final String sousTitre;
  final String? pied;
  final Color couleur;
  final VoidCallback? onFleche;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      couleur: couleur,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(label: etat),
              const Spacer(),
              StatusPill(label: plage),
            ],
          ),
          const SizedBox(height: 14),
          Text(sousTitre, style: AppText.petit),
          const SizedBox(height: 2),
          Text(titre, style: AppText.entete),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(pied ?? '', style: AppText.petit)),
              if (onFleche != null)
                RoundIconButton(
                  icone: Icons.arrow_forward,
                  onPressed: onFleche,
                  taille: 38,
                  couleur: AppColors.blanc,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
