import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:classcheck/core/data/seance_repository.dart';
import 'package:classcheck/core/models/presence.dart';
import 'package:classcheck/core/models/seance.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/auth/data/auth_repository.dart';
import 'package:classcheck/features/student/data/demandes_repository.dart';
import 'package:classcheck/features/student/data/student_repository.dart';

/// Maquette « Etudiant-Accueil ».
class EtudiantAccueilScreen extends ConsumerWidget {
  const EtudiantAccueilScreen({super.key});

  void _rafraichir(WidgetRef ref) {
    ref.invalidate(seancesDuJourProvider);
    ref.invalidate(mesPresencesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilProvider).valueOrNull;
    final seances = ref.watch(seancesDuJourProvider);
    final presences = ref.watch(mesPresencesProvider).valueOrNull ?? const <Presence>[];
    final parSeance = {for (final p in presences) p.seanceId: p};
    final taux = Assiduite(presences).taux;
    final nonLues = ref.watch(nbNonLuesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _rafraichir(ref),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.push('/profil'),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.violet,
                            child: Text(
                              Fmt.initiale(profil?.nom ?? ''),
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push('/etudiant/assiduite'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bonjour ${Fmt.prenom(profil?.nom ?? '')}',
                                    style: AppText.sousTitre),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 100,
                                  child: ProgressPill(
                                    valeur: taux,
                                    couleur: AppColors.violet,
                                    fond: AppColors.lavande,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        RoundIconButton(
                          icone: Icons.insights_outlined,
                          infobulle: 'Mon assiduité',
                          onPressed: () => context.push('/etudiant/assiduite'),
                        ),
                        const SizedBox(width: 8),
                        Badge(
                          isLabelVisible: nonLues > 0,
                          label: Text('$nonLues'),
                          backgroundColor: AppColors.bleu,
                          child: RoundIconButton(
                            icone: Icons.notifications_none_rounded,
                            infobulle: 'Notifications',
                            onPressed: () => context.push('/etudiant/notifications'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text('Vos séances\naujourd\'hui', style: AppText.grandTitre),
                        ),
                        RoundIconButton(
                          icone: Icons.calendar_month_outlined,
                          infobulle: 'Emploi du temps',
                          onPressed: () => context.push('/etudiant/emploi'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AsyncValueView<List<Seance>>(
                      valeur: seances,
                      onReessayer: () => _rafraichir(ref),
                      donnees: (liste) {
                        if (liste.isEmpty) {
                          return const VueVide(message: 'Aucune séance aujourd\'hui.');
                        }
                        return Column(
                          children: [
                            for (final s in liste) ...[
                              _CarteSeance(seance: s, presence: parSeance[s.id]),
                              const SizedBox(height: 12),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: PillButton(
                            label: 'Auto-déclaration',
                            variant: PillVariant.clair,
                            hauteur: 44,
                            icone: Icons.edit_calendar_outlined,
                            onPressed: () => context.push('/etudiant/auto-declaration'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PillButton(
                            label: 'Réclamations',
                            variant: PillVariant.clair,
                            hauteur: 44,
                            icone: Icons.gavel_rounded,
                            onPressed: () => context.push('/etudiant/reclamations'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PillButton(
                label: 'Scanner le QR',
                icone: Icons.qr_code_scanner_rounded,
                onPressed: () async {
                  await context.push('/etudiant/scan');
                  _rafraichir(ref);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteSeance extends ConsumerWidget {
  const _CarteSeance({required this.seance, this.presence});

  final Seance seance;
  final Presence? presence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = seance.etat();
    final (libelle, couleur) = switch (etat) {
      EtatSeance.enCours => ('En cours', AppColors.menthe),
      EtatSeance.aVenir => ('À venir', AppColors.lavande),
      EtatSeance.terminee => ('Terminée', AppColors.blanc),
    };

    String pied;
    if (presence != null) {
      pied = presence!.estPresent
          ? 'Présent${presence!.pointeA != null ? ' · ${Fmt.heure(presence!.pointeA!)}' : ''}'
          : 'Absent';
    } else if (seance.estOuverte) {
      final c = ref.watch(compteurSeanceProvider(seance.id)).valueOrNull;
      pied = c == null ? 'Pointage ouvert' : '${c.presents} présents sur ${c.total}';
    } else if (etat == EtatSeance.aVenir) {
      pied = 'Pointage ouvert à ${Fmt.heureSql(seance.heureDebut)}';
    } else {
      pied = seance.estCloturee ? 'Séance clôturée' : 'En attente de l\'enseignant';
    }

    final peutPointer = seance.pointageOuvert && presence == null;
    return SessionCard(
      etat: libelle,
      plage: seance.plage,
      sousTitre: '${seance.salle} · ${seance.enseignantNom ?? ''}',
      titre: seance.coursNom,
      pied: pied,
      couleur: couleur,
      onFleche: () => context.push(peutPointer ? '/etudiant/scan' : '/etudiant/emploi'),
    );
  }
}
