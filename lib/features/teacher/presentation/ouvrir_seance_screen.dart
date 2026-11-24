import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/data/seance_repository.dart';
import 'package:classcheck/core/models/seance.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/messages_erreur.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/teacher/data/teacher_repository.dart';

/// Maquette « T-OuvrirSeance » : fenêtre de pointage + options.
class OuvrirSeanceScreen extends ConsumerStatefulWidget {
  const OuvrirSeanceScreen({super.key, required this.seanceId});
  final String seanceId;

  @override
  ConsumerState<OuvrirSeanceScreen> createState() => _OuvrirSeanceScreenState();
}

class _OuvrirSeanceScreenState extends ConsumerState<OuvrirSeanceScreen> {
  static const _fenetres = [5, 10, 15, 20];
  int? _fenetre;
  bool? _visage;
  bool _chargement = false;

  Future<void> _generer(Regles regles) async {
    setState(() => _chargement = true);
    try {
      await ref.read(teacherRepositoryProvider).ouvrirSeance(
            widget.seanceId,
            fenetre: _fenetre ?? _defautFenetre(regles),
            visage: _visage ?? true,
          );
      ref.invalidate(seanceProvider(widget.seanceId));
      ref.invalidate(seancesDuJourProvider);
      if (mounted) context.pushReplacement('/enseignant/seance/${widget.seanceId}/qr');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      setState(() => _chargement = false);
    }
  }

  int _defautFenetre(Regles r) =>
      _fenetres.contains(r.fenetrePointage) ? r.fenetrePointage : 15;

  @override
  Widget build(BuildContext context) {
    final seance = ref.watch(seanceProvider(widget.seanceId));
    final regles = ref.watch(reglesProvider).valueOrNull ?? const Regles();
    final visageImpose = regles.visageObligatoire;
    final visage = visageImpose || (_visage ?? true);
    final fenetre = _fenetre ?? _defautFenetre(regles);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Ouvrir la séance', repli: '/enseignant'),
            Expanded(
              child: AsyncValueView<Seance>(
                valeur: seance,
                onReessayer: () => ref.invalidate(seanceProvider(widget.seanceId)),
                donnees: (s) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    AppCard(
                      couleur: AppColors.menthe,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.coursEtClasse, style: AppText.sousTitre),
                          Text('${s.plage} · ${s.salle}', style: AppText.petit),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text('Fenêtre de pointage', style: AppText.sousTitre),
                    const SizedBox(height: 10),
                    PillTabs<int>(
                      options: [for (final f in _fenetres) (f, '$f min')],
                      valeur: fenetre,
                      onChanged: (f) => setState(() => _fenetre = f),
                    ),
                    const SizedBox(height: 18),
                    _LigneOption(
                      titre: 'Vérification du visage',
                      sousTitre: visageImpose
                          ? 'Imposée par l\'établissement'
                          : 'Obligatoire après le scan',
                      pastille: StatusPill(
                        label: visage ? 'Activée' : 'Désactivée',
                        couleur: visage ? AppColors.texte : AppColors.puce,
                        couleurTexte: visage ? AppColors.blanc : AppColors.texte,
                        onTap: visageImpose ? null : () => setState(() => _visage = !visage),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _LigneOption(
                      titre: 'Renouvellement du QR',
                      sousTitre: 'Code change automatiquement',
                      pastille: StatusPill(
                        label: '${regles.renouvellementQr} s',
                        couleur: AppColors.lavande,
                      ),
                    ),
                    if (s.estOuverte) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Cette séance est déjà ouverte : la fenêtre en cours est conservée.',
                        style: AppText.petit,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PillButton(
                label: 'Générer le QR',
                chargement: _chargement,
                onPressed: seance.hasValue && !(seance.value!.estCloturee)
                    ? () => _generer(regles)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LigneOption extends StatelessWidget {
  const _LigneOption({required this.titre, required this.sousTitre, required this.pastille});

  final String titre;
  final String sousTitre;
  final Widget pastille;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: AppText.sousTitre.copyWith(fontSize: 13)),
                Text(sousTitre, style: AppText.petit),
              ],
            ),
          ),
          pastille,
        ],
      ),
    );
  }
}
