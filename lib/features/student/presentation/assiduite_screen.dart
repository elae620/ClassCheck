import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/models/presence.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/student/data/student_repository.dart';

/// Maquette « Etudiant-Historique » (Mon assiduité).
class AssiduiteScreen extends ConsumerWidget {
  const AssiduiteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presences = ref.watch(mesPresencesProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Mon assiduité', repli: '/etudiant'),
            Expanded(
              child: AsyncValueView<List<Presence>>(
                valeur: presences,
                onReessayer: () => ref.invalidate(mesPresencesProvider),
                donnees: (liste) => _Contenu(presences: liste),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({required this.presences});
  final List<Presence> presences;

  @override
  Widget build(BuildContext context) {
    final a = Assiduite(presences);
    final parMois = a.parMois();
    // Les 3 derniers mois (y compris le mois courant).
    final n = DateTime.now();
    final mois = [
      for (var k = 2; k >= 0; k--) DateTime(n.year, n.month - k),
    ];
    const couleurs = [AppColors.jaune, AppColors.violet, AppColors.menthe];
    final derniereAbsence =
        presences.where((p) => p.statut == 'absent' && !p.justifiee).firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                libelle: 'Présences',
                valeur: '${a.nbPresents + a.nbRetards}',
                couleur: AppColors.menthe,
                onTap: () => context.push('/etudiant/historique'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                libelle: 'Absences',
                valeur: '${a.nbAbsences}',
                couleur: AppColors.jaune,
                onTap: () => context.push('/etudiant/historique'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Progression', style: AppText.sousTitre),
        const SizedBox(height: 10),
        AppCard(
          couleur: AppColors.lavande,
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < mois.length; i++)
                _barreMois(mois[i], parMois[mois[i].year * 100 + mois[i].month], couleurs[i]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (derniereAbsence != null)
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Absence · ${derniereAbsence.seance?.coursNomCourt ?? ''}',
                          style: AppText.sousTitre.copyWith(fontSize: 13)),
                      if (derniereAbsence.seance != null)
                        Text(
                          '${Fmt.jourCourt(derniereAbsence.seance!.date)} · '
                          '${Fmt.heureSql(derniereAbsence.seance!.heureDebut)}',
                          style: AppText.petit,
                        ),
                    ],
                  ),
                ),
                PillButton.petit(
                  label: 'Réclamer',
                  onPressed: () =>
                      context.push('/etudiant/reclamation/nouvelle', extra: derniereAbsence),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => context.push('/etudiant/historique'),
            child: Text('Voir l\'historique détaillé', style: AppText.lien),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => context.push('/etudiant/reclamations'),
            child: Text('Mes réclamations', style: AppText.lien),
          ),
        ),
      ],
    );
  }

  Widget _barreMois(DateTime m, double? taux, Color couleur) {
    final t = taux ?? 0;
    return PillBar(
      valeur: t,
      libelle: taux == null ? '—' : '${(t * 100).round()} %',
      sousLibelle: 'taux',
      legende: Fmt.moisCourt(m.month),
      couleur: couleur,
      hauteur: 120,
    );
  }
}
