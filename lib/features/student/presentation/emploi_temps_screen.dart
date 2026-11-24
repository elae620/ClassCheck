import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/data/seance_repository.dart';
import 'package:classcheck/core/models/presence.dart';
import 'package:classcheck/core/models/seance.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/auth/domain/profil.dart';
import 'package:classcheck/features/student/data/student_repository.dart';

enum _Vue { jour, semaine }

/// Maquette « E-EmploiTemps » (réutilisée pour l'enseignant).
class EmploiTempsScreen extends ConsumerStatefulWidget {
  const EmploiTempsScreen({super.key, required this.role});
  final Role role;

  @override
  ConsumerState<EmploiTempsScreen> createState() => _EmploiTempsScreenState();
}

class _EmploiTempsScreenState extends ConsumerState<EmploiTempsScreen> {
  _Vue _vue = _Vue.jour;
  late final DateTime _lundi = Fmt.lundi(DateTime.now());
  late int _jour = DateTime.now().weekday > 5 ? 0 : DateTime.now().weekday - 1;

  @override
  Widget build(BuildContext context) {
    final etudiant = widget.role == Role.etudiant;
    final seances = ref.watch(seancesSemaineProvider(_lundi));
    final presences = etudiant
        ? (ref.watch(mesPresencesProvider).valueOrNull ?? const <Presence>[])
        : const <Presence>[];
    final parSeance = {for (final p in presences) p.seanceId: p};
    final jourAffiche = _vue == _Vue.jour
        ? Fmt.aujourdhui()
        : _lundi.add(Duration(days: _jour));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppBackHeader(titre: 'Emploi du temps', repli: widget.role.accueil),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PillTabs<_Vue>(
                    options: const [(_Vue.jour, 'Jour'), (_Vue.semaine, 'Semaine')],
                    valeur: _vue,
                    onChanged: (v) => setState(() => _vue = v),
                  ),
                  if (_vue == _Vue.semaine) ...[
                    const SizedBox(height: 10),
                    PillTabs<int>(
                      options: [for (var i = 0; i < 5; i++) (i, Fmt.joursCourts[i])],
                      valeur: _jour,
                      couleurInactive: AppColors.puce,
                      onChanged: (j) => setState(() => _jour = j),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(seancesSemaineProvider(_lundi));
                  if (etudiant) ref.invalidate(mesPresencesProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    AsyncValueView<List<Seance>>(
                      valeur: seances,
                      onReessayer: () => ref.invalidate(seancesSemaineProvider(_lundi)),
                      donnees: (toutes) {
                        final duJour =
                            toutes.where((s) => Fmt.memeJour(s.date, jourAffiche)).toList();
                        if (duJour.isEmpty) {
                          return VueVide(
                            message: 'Aucune séance le ${Fmt.jourCourt(jourAffiche)}.',
                          );
                        }
                        return Column(
                          children: [
                            for (final s in duJour) ...[
                              _CarteCreneau(
                                seance: s,
                                presence: parSeance[s.id],
                                role: widget.role,
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteCreneau extends StatelessWidget {
  const _CarteCreneau({required this.seance, required this.role, this.presence});

  final Seance seance;
  final Presence? presence;
  final Role role;

  static String _libelleStatut(Presence? p) {
    if (p == null) return '';
    return switch (p.statut) {
      'present' => ' · Présent',
      'retard' => ' · Retard',
      _ => ' · Absent',
    };
  }

  @override
  Widget build(BuildContext context) {
    final etat = seance.etat();
    final couleur = switch (etat) {
      EtatSeance.enCours => AppColors.menthe,
      EtatSeance.aVenir => AppColors.lavande,
      EtatSeance.terminee => AppColors.blanc,
    };
    final etudiant = role == Role.etudiant;

    String sousTitre;
    switch (etat) {
      case EtatSeance.terminee:
        sousTitre = 'Terminé${_libelleStatut(presence)}';
      case EtatSeance.enCours:
        sousTitre = '${seance.salle} · ${etudiant ? (seance.enseignantNom ?? '') : seance.classe}';
      case EtatSeance.aVenir:
        sousTitre = 'À venir · ${etudiant ? (seance.enseignantNom ?? '') : seance.classe}';
    }

    Widget? action;
    if (etudiant && seance.pointageOuvert && presence == null) {
      action = PillButton.petit(label: 'Pointer', onPressed: () => context.push('/etudiant/scan'));
    } else if (!etudiant && seance.estAujourdhui && !seance.estCloturee) {
      action = PillButton.petit(
        label: seance.estOuverte ? 'Afficher le QR' : 'Ouvrir',
        onPressed: () => context.push(seance.estOuverte
            ? '/enseignant/seance/${seance.id}/qr'
            : '/enseignant/seance/${seance.id}/ouvrir'),
      );
    }

    return AppCard(
      couleur: couleur,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(Fmt.heureSql(seance.heureDebut), style: AppText.sousTitre),
              const Spacer(),
              if (etat == EtatSeance.enCours)
                const StatusPill(label: 'En cours')
              else
                Text(seance.salle, style: AppText.petit),
            ],
          ),
          const SizedBox(height: 4),
          Text(seance.coursNom, style: AppText.sousTitre.copyWith(fontSize: 13)),
          Text(sousTitre, style: AppText.petit),
          if (action != null) ...[const SizedBox(height: 10), action],
        ],
      ),
    );
  }
}
