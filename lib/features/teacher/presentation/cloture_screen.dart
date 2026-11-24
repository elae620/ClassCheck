import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/data/seance_repository.dart';
import 'package:classcheck/core/models/presence.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/face/presentation/visage_enregistre_screen.dart';
import 'package:classcheck/features/teacher/data/teacher_repository.dart';

/// Maquette « T-Cloture » : bilan de la séance.
class ClotureScreen extends ConsumerWidget {
  const ClotureScreen({super.key, required this.seanceId});
  final String seanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seance = ref.watch(seanceProvider(seanceId)).valueOrNull;
    final presences =
        ref.watch(presencesEnDirectProvider(seanceId)).valueOrNull ?? const <Presence>[];
    final etudiants = seance == null
        ? const <EtudiantResume>[]
        : (ref.watch(etudiantsClasseProvider(seance.classe)).valueOrNull ?? const []);
    final noms = {for (final e in etudiants) e.id: e.nom};
    final nbPresents = presences.where((p) => p.estPresent).length;
    final nbAbsents = presences.where((p) => p.statut == 'absent').length;
    final auto = presences
        .where((p) => p.methode == 'auto_cloture')
        .map((p) => Fmt.nomCourt(noms[p.etudiantId] ?? 'Étudiant'))
        .toList();

    void voirListe() => context.push('/enseignant/seance/$seanceId/presents');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: '', repli: '/enseignant'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  const Center(child: CercleResultat(couleur: AppColors.menthe, icone: Icons.check)),
                  const SizedBox(height: 18),
                  Text('Séance clôturée', textAlign: TextAlign.center, style: AppText.titre),
                  if (seance != null)
                    Text(
                      '${seance.coursEtClasse} · '
                      '${seance.clotureeA == null ? Fmt.heureSql(seance.heureFin) : Fmt.heure(seance.clotureeA!)}',
                      textAlign: TextAlign.center,
                      style: AppText.secondaire,
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          libelle: 'Présents',
                          valeur: '$nbPresents',
                          couleur: AppColors.menthe,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          libelle: 'Absents',
                          valeur: '$nbAbsents',
                          couleur: AppColors.rose,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Absents automatiques',
                                  style: AppText.sousTitre.copyWith(fontSize: 13)),
                              Text(auto.isEmpty ? 'Aucun' : auto.join(', '),
                                  style: AppText.petit),
                            ],
                          ),
                        ),
                        StatusPill(label: 'Voir', couleur: AppColors.lavande, onTap: voirListe),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PillButton(label: 'Voir le rapport', onPressed: voirListe),
            ),
          ],
        ),
      ),
    );
  }
}
