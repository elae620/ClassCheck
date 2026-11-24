import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/data/suivi_repository.dart';
import 'package:classcheck/core/models/sprint2.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/widgets/widgets.dart';

/// Période d'analyse du tableau de bord et de l'export.
enum Periode {
  semaine('Semaine', 7),
  mois('Mois', 30),
  semestre('Semestre', 182),
  tout('Tout', 0);

  const Periode(this.libelle, this.jours);
  final String libelle;
  final int jours;

  FiltreStats filtre({String? classe, String? coursId}) => FiltreStats(
        debut: jours == 0 ? null : Fmt.aujourdhui().subtract(Duration(days: jours)),
        fin: jours == 0 ? null : Fmt.aujourdhui(),
        classe: classe,
        coursId: coursId,
      );
}

/// Maquette « Directeur-Tableau » (Vue d'ensemble).
class DirecteurTableauScreen extends ConsumerStatefulWidget {
  const DirecteurTableauScreen({super.key});

  @override
  ConsumerState<DirecteurTableauScreen> createState() => _DirecteurTableauScreenState();
}

class _DirecteurTableauScreenState extends ConsumerState<DirecteurTableauScreen> {
  Periode _periode = Periode.tout;
  String? _classe;
  String? _coursId;

  @override
  void initState() {
    super.initState();
    // Les séances oubliées sont clôturées automatiquement (non-pointés → absents).
    Future.microtask(
        () => ref.read(suiviRepositoryProvider).cloturerSeancesPassees().catchError((_) => 0));
  }

  void _rafraichir() {
    ref.invalidate(statsProvider);
    ref.invalidate(etudiantsARisqueProvider);
    ref.invalidate(reclamationsProvider('transmise'));
  }

  @override
  Widget build(BuildContext context) {
    final filtre = _periode.filtre(classe: _classe, coursId: _coursId);
    final stats = ref.watch(statsProvider(filtre));
    // Liste complète des classes / matières pour les filtres.
    final global = ref.watch(statsProvider(_periode.filtre())).valueOrNull;
    final risque = ref.watch(etudiantsARisqueProvider).valueOrNull ?? const <EtudiantARisque>[];
    final litiges = ref.watch(reclamationsProvider('transmise')).valueOrNull ?? const <Reclamation>[];
    final nbRisque = {for (final r in risque) r.etudiantId}.length;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _rafraichir(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text('Vue\nd\'ensemble', style: AppText.grandTitre)),
                  RoundIconButton(
                    icone: Icons.file_download_outlined,
                    infobulle: 'Exporter',
                    onPressed: () => context.push('/directeur/export'),
                  ),
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icone: Icons.person_outline,
                    infobulle: 'Mon profil',
                    onPressed: () => context.push('/profil'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              PillTabs<Periode>(
                options: [for (final p in Periode.values) (p, p.libelle)],
                valeur: _periode,
                onChanged: (p) => setState(() => _periode = p),
              ),
              if (global != null && (global.parClasse.length > 1 || global.parCours.length > 1)) ...[
                const SizedBox(height: 8),
                PillTabs<String?>(
                  options: [
                    (null, 'Toutes les classes'),
                    for (final c in global.parClasse) (c.libelle, c.libelle),
                  ],
                  valeur: _classe,
                  onChanged: (c) => setState(() => _classe = c),
                ),
                const SizedBox(height: 8),
                PillTabs<String?>(
                  options: [
                    (null, 'Toutes les matières'),
                    for (final c in global.parCours) (c.id, c.libelle.split(' · ').first),
                  ],
                  valeur: _coursId,
                  onChanged: (c) => setState(() => _coursId = c),
                ),
              ],
              const SizedBox(height: 14),
              AsyncValueView(
                valeur: stats,
                onReessayer: _rafraichir,
                donnees: (StatsPresences s) => Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            libelle: 'Présence',
                            valeur: '${s.tauxPourcent} %',
                            couleur: AppColors.menthe,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            libelle: 'À risque',
                            valeur: '$nbRisque',
                            couleur: AppColors.rose,
                            onTap: () => context.push('/directeur/risque'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.parClasse.length > 1 ? 'Absences par classe' : 'Absences par matière',
                            style: AppText.sousTitre,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _BarresAbsences(stats: s),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (litiges.isNotEmpty)
                AppCard(
                  couleur: AppColors.jaune,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Réclamation litigieuse', style: AppText.sousTitre),
                          ),
                          StatusPill(label: '${litiges.length} en attente'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${Fmt.nomCourt(litiges.first.etudiantNom ?? '')} · '
                        '${litiges.first.seance?.coursNomCourt ?? ''}, '
                        '${litiges.first.seance == null ? '' : Fmt.jourCourt(litiges.first.seance!.date)}'
                        '${litiges.first.avisEnseignant == null ? '' : ' · refusée par l\'enseignant'}',
                        style: AppText.petit,
                      ),
                      const SizedBox(height: 10),
                      PillButton.petit(
                        label: 'Trancher',
                        onPressed: () async {
                          await context.push('/directeur/reclamation/${litiges.first.id}');
                          _rafraichir();
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: [
                  const _Raccourci(Icons.warning_amber_rounded, 'À risque', '/directeur/risque', AppColors.rose),
                  const _Raccourci(Icons.gavel_rounded, 'Réclamations', '/directeur/reclamations', AppColors.jaune),
                  const _Raccourci(Icons.history_rounded, 'Audit', '/directeur/audit', AppColors.lavande),
                  const _Raccourci(Icons.tune_rounded, 'Règles', '/directeur/regles', AppColors.menthe),
                  const _Raccourci(Icons.manage_accounts_outlined, 'Gestion', '/directeur/gestion', AppColors.violet),
                  const _Raccourci(Icons.file_download_outlined, 'Export', '/directeur/export', AppColors.blanc),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarresAbsences extends StatelessWidget {
  const _BarresAbsences({required this.stats});
  final StatsPresences stats;

  @override
  Widget build(BuildContext context) {
    final groupes = stats.parClasse.length > 1 ? stats.parClasse : stats.parCours;
    if (groupes.isEmpty) return const VueVide(message: 'Aucune donnée pour cette période.');
    const couleurs = [AppColors.jaune, AppColors.violet, AppColors.menthe, AppColors.rose];
    return AppCard(
      couleur: AppColors.lavande,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < groupes.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: PillBar(
                  // Hauteur proportionnelle au taux d'absence (×4 pour rester lisible).
                  valeur: ((1 - groupes[i].taux) * 4).clamp(0.0, 1.0),
                  libelle: '${((1 - groupes[i].taux) * 100).round()} %',
                  sousLibelle: 'abs.',
                  legende: groupes[i].libelle.split(' · ').first,
                  couleur: couleurs[i % couleurs.length],
                  hauteur: 120,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Raccourci extends StatelessWidget {
  const _Raccourci(this.icone, this.libelle, this.route, this.couleur);
  final IconData icone;
  final String libelle;
  final String route;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      couleur: couleur,
      rayon: 22,
      padding: const EdgeInsets.all(10),
      onTap: () => context.push(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: 26),
          const SizedBox(height: 6),
          Text(libelle, style: AppText.petit.copyWith(color: AppColors.texte), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
