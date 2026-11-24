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
import 'package:classcheck/features/teacher/data/teacher_repository.dart';
import 'package:classcheck/features/teacher/presentation/cloture_action.dart';

enum _Filtre { tous, presents, absents }

/// Maquette « T-Presents » : liste en temps réel (Realtime).
class PresentsScreen extends ConsumerStatefulWidget {
  const PresentsScreen({super.key, required this.seanceId});
  final String seanceId;

  @override
  ConsumerState<PresentsScreen> createState() => _PresentsScreenState();
}

class _PresentsScreenState extends ConsumerState<PresentsScreen> {
  _Filtre _filtre = _Filtre.tous;

  @override
  Widget build(BuildContext context) {
    final seance = ref.watch(seanceProvider(widget.seanceId));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Présents en direct', repli: '/enseignant'),
            Expanded(
              child: AsyncValueView<Seance>(
                valeur: seance,
                onReessayer: () => ref.invalidate(seanceProvider(widget.seanceId)),
                donnees: (s) => _Liste(seance: s, filtre: _filtre, onFiltre: (f) {
                  setState(() => _filtre = f);
                }),
              ),
            ),
            if (seance.valueOrNull?.estOuverte ?? false)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: PillButton(
                  label: 'Clôturer la séance',
                  onPressed: () => cloturerSeance(context, ref, seance.value!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Liste extends ConsumerWidget {
  const _Liste({required this.seance, required this.filtre, required this.onFiltre});

  final Seance seance;
  final _Filtre filtre;
  final ValueChanged<_Filtre> onFiltre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presencesAsync = ref.watch(presencesEnDirectProvider(seance.id));
    final etudiantsAsync = ref.watch(etudiantsClasseProvider(seance.classe));
    final presences = presencesAsync.valueOrNull ?? const <Presence>[];
    final etudiants = etudiantsAsync.valueOrNull ?? const <EtudiantResume>[];
    final parEtudiant = {for (final p in presences) p.etudiantId: p};
    final nbPresents = presences.where((p) => p.estPresent).length;

    final lignes = etudiants.where((e) {
      final p = parEtudiant[e.id];
      return switch (filtre) {
        _Filtre.tous => true,
        _Filtre.presents => p != null && p.estPresent,
        _Filtre.absents => p == null || !p.estPresent,
      };
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        AppCard(
          couleur: AppColors.menthe,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text(seance.coursEtClasse, style: AppText.petit)),
                  Text('$nbPresents / ${etudiants.length}', style: AppText.titre),
                ],
              ),
              const SizedBox(height: 10),
              ProgressPill(
                valeur: etudiants.isEmpty ? 0 : nbPresents / etudiants.length,
                couleur: AppColors.bleu,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PillTabs<_Filtre>(
          options: const [
            (_Filtre.tous, 'Tous'),
            (_Filtre.presents, 'Présents'),
            (_Filtre.absents, 'Absents'),
          ],
          valeur: filtre,
          onChanged: onFiltre,
        ),
        const SizedBox(height: 12),
        if (presencesAsync.hasError || etudiantsAsync.hasError)
          const VueErreur(message: 'Connexion temps réel interrompue. Revenez sur l\'écran.'),
        if (etudiantsAsync.isLoading) const Chargement(),
        if (!etudiantsAsync.isLoading && lignes.isEmpty)
          const VueVide(message: 'Aucun étudiant dans cette catégorie.'),
        for (final e in lignes) ...[
          _LigneEtudiant(
            nom: e.nom,
            presence: parEtudiant[e.id],
            cloturee: seance.estCloturee,
            onTap: () => context.push('/enseignant/seance/${seance.id}/correction/${e.id}'),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _LigneEtudiant extends StatelessWidget {
  const _LigneEtudiant({
    required this.nom,
    required this.presence,
    required this.cloturee,
    this.onTap,
  });

  final String nom;
  final Presence? presence;
  final bool cloturee;

  /// Ouvre la correction manuelle (T-Correction).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = presence;
    final detail = p == null
        ? 'Pas encore pointé'
        : (p.pointeA == null ? p.libelleMethode : '${Fmt.heure(p.pointeA!)} · ${p.libelleMethode}');
    return AppCard(
      rayon: 20,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Fmt.nomCourt(nom), style: AppText.sousTitre.copyWith(fontSize: 13)),
                Text(detail, style: AppText.petit),
              ],
            ),
          ),
          StatusPill.presence(p?.statut ?? (cloturee ? 'absent' : 'attente')),
        ],
      ),
    );
  }
}
