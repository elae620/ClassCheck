import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/models/presence.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/student/data/student_repository.dart';

/// Maquette « Historique » : filtrable par cours, avec taux d'assiduité.
class HistoriqueScreen extends ConsumerStatefulWidget {
  const HistoriqueScreen({super.key});

  @override
  ConsumerState<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends ConsumerState<HistoriqueScreen> {
  String? _cours; // null = toutes

  @override
  Widget build(BuildContext context) {
    final presences = ref.watch(mesPresencesProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Historique', repli: '/etudiant'),
            Expanded(
              child: AsyncValueView<List<Presence>>(
                valeur: presences,
                onReessayer: () => ref.invalidate(mesPresencesProvider),
                donnees: (toutes) {
                  final cours = <String, String>{
                    for (final p in toutes)
                      if (p.seance != null) p.seance!.coursId: p.seance!.coursNomCourt,
                  };
                  final filtrees = _cours == null
                      ? toutes
                      : toutes.where((p) => p.seance?.coursId == _cours).toList();
                  final a = Assiduite(filtrees);
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(mesPresencesProvider),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        PillTabs<String?>(
                          options: [
                            (null, 'Toutes'),
                            for (final e in cours.entries) (e.key, e.value),
                          ],
                          valeur: _cours,
                          onChanged: (c) => setState(() => _cours = c),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                libelle: 'Assiduité',
                                valeur: '${a.tauxPourcent} %',
                                couleur: AppColors.menthe,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StatCard(
                                libelle: 'Retards',
                                valeur: '${a.nbRetards}',
                                couleur: AppColors.jaune,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (filtrees.isEmpty)
                          const VueVide(message: 'Aucune séance pour ce filtre.'),
                        for (final p in filtrees) ...[
                          _LignePresence(presence: p),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LignePresence extends StatelessWidget {
  const _LignePresence({required this.presence});
  final Presence presence;

  @override
  Widget build(BuildContext context) {
    final s = presence.seance;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      rayon: 20,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s == null ? 'Séance' : '${s.coursNomCourt} · ${Fmt.jourCourt(s.date)}',
                  style: AppText.sousTitre.copyWith(fontSize: 13),
                ),
                if (s != null) Text(s.plage, style: AppText.petit),
              ],
            ),
          ),
          if (presence.statut == 'absent' && !presence.justifiee) ...[
            StatusPill(
              label: 'Réclamer',
              couleur: AppColors.lavande,
              onTap: () => context.push('/etudiant/reclamation/nouvelle', extra: presence),
            ),
            const SizedBox(width: 6),
          ],
          if (presence.justifiee)
            const StatusPill(label: 'Justifiée', couleur: AppColors.menthe)
          else
            StatusPill.presence(presence.statut),
        ],
      ),
    );
  }
}
