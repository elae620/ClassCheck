import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/data/seance_repository.dart';
import 'package:classcheck/core/data/suivi_repository.dart';
import 'package:classcheck/core/models/seance.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/auth/data/auth_repository.dart';
import 'package:classcheck/features/teacher/data/teacher_repository.dart';

/// Maquette « T-Accueil ».
class EnseignantAccueilScreen extends ConsumerStatefulWidget {
  const EnseignantAccueilScreen({super.key});

  @override
  ConsumerState<EnseignantAccueilScreen> createState() => _EnseignantAccueilScreenState();
}

class _EnseignantAccueilScreenState extends ConsumerState<EnseignantAccueilScreen> {
  @override
  void initState() {
    super.initState();
    // Séances oubliées des jours précédents : clôture automatique (non-pointés → absents).
    Future.microtask(() async {
      try {
        final n = await ref.read(suiviRepositoryProvider).cloturerSeancesPassees();
        if (n > 0) ref.invalidate(seancesDuJourProvider);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final aTraiter = ref.watch(autoDeclarationsEnAttenteProvider).valueOrNull?.length ?? 0;
    final reclamations = ref.watch(reclamationsProvider('en_attente')).valueOrNull?.length ?? 0;
    final profil = ref.watch(profilProvider).valueOrNull;
    final seances = ref.watch(seancesDuJourProvider);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(seancesDuJourProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text('Bonjour\n${profil?.nom ?? ''}', style: AppText.grandTitre),
                  ),
                  RoundIconButton(
                    icone: Icons.calendar_month_outlined,
                    infobulle: 'Emploi du temps',
                    onPressed: () => context.push('/enseignant/emploi'),
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
              Row(
                children: [
                  _Raccourci(
                    icone: Icons.edit_calendar_outlined,
                    libelle: 'Auto-décl.',
                    compteur: aTraiter,
                    couleur: AppColors.jaune,
                    onTap: () async {
                      await context.push('/enseignant/auto-declarations');
                      ref.invalidate(autoDeclarationsEnAttenteProvider);
                    },
                  ),
                  const SizedBox(width: 8),
                  _Raccourci(
                    icone: Icons.gavel_rounded,
                    libelle: 'Réclamations',
                    compteur: reclamations,
                    couleur: AppColors.rose,
                    onTap: () async {
                      await context.push('/enseignant/reclamations');
                      ref.invalidate(reclamationsProvider('en_attente'));
                    },
                  ),
                  const SizedBox(width: 8),
                  _Raccourci(
                    icone: Icons.insights_outlined,
                    libelle: 'Statistiques',
                    couleur: AppColors.lavande,
                    onTap: () => context.push('/enseignant/stats'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Mes séances du jour', style: AppText.sousTitre),
              const SizedBox(height: 12),
              AsyncValueView<List<Seance>>(
                valeur: seances,
                onReessayer: () => ref.invalidate(seancesDuJourProvider),
                donnees: (liste) {
                  if (liste.isEmpty) {
                    return const VueVide(message: 'Aucune séance aujourd\'hui.');
                  }
                  // La première séance non terminée est mise en avant (carte menthe).
                  final indexActive =
                      liste.indexWhere((s) => s.etat() != EtatSeance.terminee);
                  return Column(
                    children: [
                      for (var i = 0; i < liste.length; i++) ...[
                        _CarteSeanceEnseignant(seance: liste[i], active: i == indexActive),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarteSeanceEnseignant extends ConsumerWidget {
  const _CarteSeanceEnseignant({required this.seance, required this.active});

  final Seance seance;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectif = ref.watch(etudiantsClasseProvider(seance.classe)).valueOrNull?.length;
    final etat = seance.etat();
    final couleur = active
        ? AppColors.menthe
        : (etat == EtatSeance.terminee ? AppColors.blanc : AppColors.lavande);
    final badge = seance.estCloturee
        ? 'Clôturée'
        : seance.estOuverte
            ? 'Ouverte'
            : (etat == EtatSeance.enCours ? 'Maintenant' : null);

    final (libelleAction, route) = seance.estCloturee
        ? ('Voir le bilan', '/enseignant/seance/${seance.id}/cloture')
        : seance.estOuverte
            ? ('Afficher le QR', '/enseignant/seance/${seance.id}/qr')
            : ('Ouvrir la séance', '/enseignant/seance/${seance.id}/ouvrir');

    final effectifTexte = effectif == null ? '' : '$effectif étudiants';
    return AppCard(
      couleur: couleur,
      onTap: () async {
        await context.push(route);
        ref.invalidate(seancesDuJourProvider);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(seance.plage, style: AppText.sousTitre),
              const Spacer(),
              if (badge != null)
                StatusPill(label: badge)
              else
                Text(seance.salle, style: AppText.petit),
            ],
          ),
          const SizedBox(height: 4),
          Text(seance.coursEtClasse, style: AppText.sousTitre),
          Text(
            active ? '${seance.salle} · $effectifTexte' : effectifTexte,
            style: AppText.petit,
          ),
          if (active) ...[
            const SizedBox(height: 12),
            PillButton.petit(
              label: libelleAction,
              onPressed: () async {
                await context.push(route);
                ref.invalidate(seancesDuJourProvider);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Raccourci extends StatelessWidget {
  const _Raccourci({
    required this.icone,
    required this.libelle,
    required this.couleur,
    required this.onTap,
    this.compteur = 0,
  });

  final IconData icone;
  final String libelle;
  final Color couleur;
  final VoidCallback onTap;
  final int compteur;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        couleur: couleur,
        rayon: 22,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Badge(
              isLabelVisible: compteur > 0,
              label: Text('$compteur'),
              backgroundColor: AppColors.texte,
              child: Icon(icone),
            ),
            const SizedBox(height: 4),
            Text(libelle, style: AppText.petit.copyWith(color: AppColors.texte), maxLines: 1),
          ],
        ),
      ),
    );
  }
}
