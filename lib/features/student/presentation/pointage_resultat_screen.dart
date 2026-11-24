import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/data/seance_repository.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/utils/messages_erreur.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/face/presentation/visage_enregistre_screen.dart';
import 'package:classcheck/features/student/data/student_repository.dart';
import 'package:classcheck/features/student/domain/pointage.dart';

/// Maquettes « E-PointageOK » et « E-PointageRefuse ».
class PointageResultatScreen extends ConsumerWidget {
  const PointageResultatScreen({super.key, required this.resultat});
  final ResultatPointage resultat;

  void _accueil(BuildContext context, WidgetRef ref) {
    ref.invalidate(seancesDuJourProvider);
    ref.invalidate(mesPresencesProvider);
    context.go('/etudiant');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = resultat;
    final details = [
      if (r.coursNom.isNotEmpty) r.coursNom,
      if (r.heure != null) Fmt.heure(r.heure!),
      if (r.salle.isNotEmpty) r.salle,
    ].join(' · ');

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Spacer(),
              CercleResultat(
                couleur: r.ok ? AppColors.menthe : AppColors.rose,
                icone: r.ok ? Icons.check : Icons.close,
              ),
              const SizedBox(height: 22),
              Text(r.ok ? 'Présence validée' : 'Pointage refusé', style: AppText.titre),
              const SizedBox(height: 6),
              Text(
                r.ok
                    ? details
                    : 'Votre présence n\'a pas été enregistrée',
                textAlign: TextAlign.center,
                style: AppText.secondaire,
              ),
              const SizedBox(height: 22),
              AppCard(
                couleur: r.ok ? AppColors.lavande : AppColors.jaune,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (libelle, valeur) in r.lignes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(libelle, style: AppText.petit)),
                            Text(valeur, style: AppText.sousTitre.copyWith(fontSize: 13)),
                          ],
                        ),
                      ),
                    if (!r.ok) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${libellesCodes[r.code] ?? 'Erreur inconnue.'} '
                        'Si le problème continue, prévenez l\'enseignant.',
                        style: AppText.petit,
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(flex: 2),
              if (r.ok)
                PillButton(label: 'Retour à l\'accueil', onPressed: () => _accueil(context, ref))
              else
                Row(
                  children: [
                    Expanded(
                      child: PillButton(
                        label: 'Annuler',
                        variant: PillVariant.clair,
                        onPressed: () => _accueil(context, ref),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PillButton(
                        label: 'Réessayer',
                        onPressed: () => context.pushReplacement('/etudiant/scan'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
