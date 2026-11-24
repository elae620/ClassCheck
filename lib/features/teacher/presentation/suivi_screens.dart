import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/data/seance_repository.dart';
import 'package:classcheck/core/data/suivi_repository.dart';
import 'package:classcheck/core/models/presence.dart';
import 'package:classcheck/core/models/seance.dart';
import 'package:classcheck/core/models/sprint2.dart';
import 'package:classcheck/core/supabase/supabase_providers.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/student/data/demandes_repository.dart';
import 'package:classcheck/features/student/presentation/demandes_screens.dart';
import 'package:classcheck/features/teacher/data/teacher_repository.dart';

String _seanceCourte(Seance? s) => s == null
    ? 'Séance'
    : '${s.coursNomCourt} · ${Fmt.jourCourt(s.date)} · ${Fmt.heureSql(s.heureDebut)}';

// =====================================================================
// T-Correction : correction manuelle avec motif obligatoire
// =====================================================================

class CorrectionScreen extends ConsumerStatefulWidget {
  const CorrectionScreen({super.key, required this.seanceId, required this.etudiantId});
  final String seanceId;
  final String etudiantId;

  @override
  ConsumerState<CorrectionScreen> createState() => _CorrectionScreenState();
}

class _CorrectionScreenState extends ConsumerState<CorrectionScreen> {
  final _form = GlobalKey<FormState>();
  final _motif = TextEditingController();
  String? _statut;
  bool _envoi = false;

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (_statut == null || !_form.currentState!.validate()) return;
    setState(() => _envoi = true);
    final ok = await executerAction(
      context,
      () => ref.read(suiviRepositoryProvider).corrigerPresence(
            seanceId: widget.seanceId,
            etudiantId: widget.etudiantId,
            statut: _statut!,
            motif: _motif.text,
          ),
      succes: 'Correction enregistrée dans le journal d\'audit.',
    );
    if (!mounted) return;
    setState(() => _envoi = false);
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final seance = ref.watch(seanceProvider(widget.seanceId)).valueOrNull;
    final presences = ref.watch(presencesEnDirectProvider(widget.seanceId)).valueOrNull ?? const [];
    final etudiants = seance == null
        ? const <EtudiantResume>[]
        : ref.watch(etudiantsClasseProvider(seance.classe)).valueOrNull ?? const [];
    final nom = etudiants.where((e) => e.id == widget.etudiantId).firstOrNull?.nom ?? 'Étudiant';
    final Presence? actuelle = presences.where((p) => p.etudiantId == widget.etudiantId).firstOrNull;
    final statutActuel = actuelle?.statut;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Correction manuelle', repli: '/enseignant'),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    AppCard(
                      couleur: AppColors.lavande,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(Fmt.nomCourt(nom), style: AppText.titre),
                                Text(_seanceCourte(seance), style: AppText.petit),
                              ],
                            ),
                          ),
                          StatusPill.presence(statutActuel ?? 'attente'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text('Nouveau statut', style: AppText.petit),
                    ),
                    PillTabs<String?>(
                      etirer: true,
                      options: const [('present', 'Présent'), ('retard', 'Retard'), ('absent', 'Absent')],
                      valeur: _statut,
                      onChanged: (s) => setState(() => _statut = s),
                    ),
                    const SizedBox(height: 16),
                    PillField(
                      libelle: 'Motif obligatoire',
                      controller: _motif,
                      lignes: 3,
                      indice: 'Ex. : caméra du téléphone en panne',
                      validator: (v) => (v ?? '').trim().length < 3 ? 'Le motif est obligatoire' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 18, color: AppColors.texteSecondaire),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Cette modification sera enregistrée dans le journal d\'audit.',
                              style: AppText.petit),
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
                label: 'Enregistrer la correction',
                chargement: _envoi,
                onPressed: _statut == null || _statut == statutActuel ? null : _enregistrer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// T-AutoDecl : validation des auto-déclarations
// =====================================================================

class AutoDeclarationsEnseignantScreen extends ConsumerWidget {
  const AutoDeclarationsEnseignantScreen({super.key});

  Future<void> _traiter(BuildContext context, WidgetRef ref, AutoDeclaration d, bool valider) async {
    String? motif;
    if (!valider) {
      motif = await demanderMotif(context, titre: 'Motif du refus', libelleBouton: 'Refuser');
      if (motif == null) return;
    }
    if (!context.mounted) return;
    final ok = await executerAction(
      context,
      () => ref.read(suiviRepositoryProvider).traiterAutoDeclaration(d.id, valider: valider, motif: motif),
      succes: valider ? 'Déclaration validée.' : 'Déclaration refusée.',
    );
    if (ok) ref.invalidate(autoDeclarationsEnAttenteProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decl = ref.watch(autoDeclarationsEnAttenteProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Auto-déclarations', repli: '/enseignant'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(autoDeclarationsEnAttenteProvider),
                child: AsyncValueView<List<AutoDeclaration>>(
                  valeur: decl,
                  onReessayer: () => ref.invalidate(autoDeclarationsEnAttenteProvider),
                  donnees: (liste) => liste.isEmpty
                      ? ListView(children: const [
                          VueVide(message: 'Aucune déclaration en attente.', icone: Icons.done_all),
                        ])
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: [
                            for (final d in liste) ...[
                              AppCard(
                                couleur: d.type == 'retard' ? AppColors.jaune : AppColors.lavande,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(Fmt.nomCourt(d.etudiantNom ?? 'Étudiant'),
                                              style: AppText.sousTitre),
                                        ),
                                        StatusPill(label: d.libelleType),
                                      ],
                                    ),
                                    Text(_seanceCourte(d.seance), style: AppText.petit),
                                    const SizedBox(height: 6),
                                    Text(d.motif, style: AppText.corps),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        PillButton.petit(
                                          label: 'Valider',
                                          onPressed: () => _traiter(context, ref, d, true),
                                        ),
                                        const SizedBox(width: 8),
                                        PillButton.petit(
                                          label: 'Refuser',
                                          variant: PillVariant.clair,
                                          onPressed: () => _traiter(context, ref, d, false),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// T-Reclamations (liste) — partagé avec le directeur
// =====================================================================

class ReclamationsSuiviScreen extends ConsumerStatefulWidget {
  const ReclamationsSuiviScreen({super.key, this.directeur = false});
  final bool directeur;

  @override
  ConsumerState<ReclamationsSuiviScreen> createState() => _ReclamationsSuiviScreenState();
}

class _ReclamationsSuiviScreenState extends ConsumerState<ReclamationsSuiviScreen> {
  late String? _statut = widget.directeur ? 'transmise' : 'en_attente';

  @override
  Widget build(BuildContext context) {
    final liste = ref.watch(reclamationsProvider(_statut));
    final base = widget.directeur ? '/directeur' : '/enseignant';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppBackHeader(titre: 'Réclamations', repli: base),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: PillTabs<String?>(
                options: [
                  if (widget.directeur) ('transmise', 'Litiges'),
                  ('en_attente', 'En attente'),
                  (null, 'Toutes'),
                ],
                valeur: _statut,
                onChanged: (s) => setState(() => _statut = s),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(reclamationsProvider(_statut)),
                child: AsyncValueView<List<Reclamation>>(
                  valeur: liste,
                  onReessayer: () => ref.invalidate(reclamationsProvider(_statut)),
                  donnees: (l) => l.isEmpty
                      ? ListView(children: const [
                          VueVide(message: 'Aucune réclamation.', icone: Icons.inbox_outlined),
                        ])
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            for (final r in l) ...[
                              AppCard(
                                rayon: 22,
                                onTap: () async {
                                  await context.push('$base/reclamation/${r.id}');
                                  ref.invalidate(reclamationsProvider(_statut));
                                },
                                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(Fmt.nomCourt(r.etudiantNom ?? 'Étudiant'),
                                              style: AppText.sousTitre.copyWith(fontSize: 13)),
                                          Text(_seanceCourte(r.seance), style: AppText.petit),
                                        ],
                                      ),
                                    ),
                                    pillDemande(r.statut),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// T-Reclamation (détail) / D-Decision (décision finale du directeur)
// =====================================================================

final _urlJustificatifProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, chemin) => urlJustificatif(ref.watch(supabaseProvider), chemin),
);

class ReclamationDetailScreen extends ConsumerStatefulWidget {
  const ReclamationDetailScreen({super.key, required this.id, this.directeur = false});
  final String id;
  final bool directeur;

  @override
  ConsumerState<ReclamationDetailScreen> createState() => _ReclamationDetailScreenState();
}

class _ReclamationDetailScreenState extends ConsumerState<ReclamationDetailScreen> {
  final _commentaire = TextEditingController();
  String? _enCours;

  @override
  void dispose() {
    _commentaire.dispose();
    super.dispose();
  }

  Future<void> _decider(String decision) async {
    if (_commentaire.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajoutez un commentaire : il est enregistré dans l\'audit.')));
      return;
    }
    setState(() => _enCours = decision);
    final ok = await executerAction(
      context,
      () => ref.read(suiviRepositoryProvider).traiterReclamation(widget.id, decision, _commentaire.text),
      succes: 'Décision enregistrée. L\'étudiant est notifié.',
    );
    if (!mounted) return;
    setState(() => _enCours = null);
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(reclamationProvider(widget.id));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppBackHeader(
              titre: widget.directeur ? 'Décision finale' : 'Réclamation',
              repli: widget.directeur ? '/directeur' : '/enseignant',
            ),
            Expanded(
              child: AsyncValueView<Reclamation>(
                valeur: r,
                onReessayer: () => ref.invalidate(reclamationProvider(widget.id)),
                donnees: (rec) => _contenu(rec),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenu(Reclamation rec) {
    final traitable = widget.directeur
        ? (rec.statut == 'transmise' || rec.statut == 'en_attente')
        : rec.statut == 'en_attente';
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              AppCard(
                couleur: AppColors.lavande,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Fmt.nomCourt(rec.etudiantNom ?? 'Étudiant'), style: AppText.titre),
                          Text(_seanceCourte(rec.seance), style: AppText.petit),
                        ],
                      ),
                    ),
                    widget.directeur && rec.statut == 'transmise'
                        ? const StatusPill(label: 'Litige', couleur: AppColors.rose)
                        : pillDemande(rec.statut),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.directeur ? 'Motif de l\'étudiant' : 'Motif', style: AppText.petit),
                    const SizedBox(height: 4),
                    Text(rec.motif, style: AppText.corps),
                  ],
                ),
              ),
              if (rec.avisEnseignant != null) ...[
                const SizedBox(height: 12),
                AppCard(
                  couleur: AppColors.jaune,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Avis de l\'enseignant', style: AppText.petit),
                      const SizedBox(height: 4),
                      Text(rec.avisEnseignant!, style: AppText.corps),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text('Justificatif (photo)', style: AppText.petit),
              ),
              if (rec.justificatif == null)
                const AppCard(child: Text('Aucun justificatif joint.'))
              else
                ref.watch(_urlJustificatifProvider(rec.justificatif!)).when(
                      data: (url) => ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: InteractiveViewer(
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const AppCard(child: Text('Justificatif illisible (PDF ?)')),
                          ),
                        ),
                      ),
                      loading: () => const Chargement(),
                      error: (e, _) => const AppCard(child: Text('Justificatif inaccessible.')),
                    ),
              if (traitable) ...[
                const SizedBox(height: 14),
                PillField(
                  libelle: widget.directeur ? 'Commentaire de décision' : 'Commentaire (obligatoire)',
                  controller: _commentaire,
                  lignes: 3,
                ),
              ] else if (rec.commentaireDecision != null) ...[
                const SizedBox(height: 12),
                AppCard(
                  couleur: AppColors.menthe,
                  child: Text('Décision : ${rec.commentaireDecision}', style: AppText.corps),
                ),
              ],
            ],
          ),
        ),
        if (traitable)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: widget.directeur
                ? Row(
                    children: [
                      Expanded(
                        child: PillButton(
                          label: rec.statut == 'transmise' ? 'Maintenir le refus' : 'Refuser',
                          variant: PillVariant.clair,
                          chargement: _enCours == 'refusee',
                          onPressed: _enCours == null ? () => _decider('refusee') : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PillButton(
                          label: 'Accepter',
                          chargement: _enCours == 'acceptee',
                          onPressed: _enCours == null ? () => _decider('acceptee') : null,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: PillButton(
                              label: 'Accepter',
                              chargement: _enCours == 'acceptee',
                              onPressed: _enCours == null ? () => _decider('acceptee') : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PillButton(
                              label: 'Refuser',
                              variant: PillVariant.clair,
                              chargement: _enCours == 'refusee',
                              onPressed: _enCours == null ? () => _decider('refusee') : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      PillButton(
                        label: 'Transmettre au directeur',
                        variant: PillVariant.violet,
                        chargement: _enCours == 'transmise',
                        onPressed: _enCours == null ? () => _decider('transmise') : null,
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}

// =====================================================================
// T-Stats : statistiques par cours et par étudiant
// =====================================================================

class StatistiquesScreen extends ConsumerStatefulWidget {
  const StatistiquesScreen({super.key});

  @override
  ConsumerState<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

class _StatistiquesScreenState extends ConsumerState<StatistiquesScreen> {
  bool _parEtudiant = false;
  String? _coursId;

  @override
  Widget build(BuildContext context) {
    final tout = ref.watch(statsProvider(const FiltreStats()));
    final filtre = FiltreStats(coursId: _coursId);
    final stats = ref.watch(statsProvider(filtre));
    final cours = tout.valueOrNull?.parCours ?? const <StatGroupe>[];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Statistiques', repli: '/enseignant'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                children: [
                  PillTabs<bool>(
                    etirer: true,
                    options: const [(false, 'Par cours'), (true, 'Par étudiant')],
                    valeur: _parEtudiant,
                    onChanged: (v) => setState(() => _parEtudiant = v),
                  ),
                  if (cours.length > 1) ...[
                    const SizedBox(height: 8),
                    PillTabs<String?>(
                      options: [(null, 'Tous'), for (final c in cours) (c.id, c.libelle)],
                      valeur: _coursId,
                      onChanged: (c) => setState(() => _coursId = c),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: AsyncValueView<StatsPresences>(
                valeur: stats,
                onReessayer: () => ref.invalidate(statsProvider(filtre)),
                donnees: (s) => _parEtudiant ? _VueEtudiants(stats: s) : _VueCours(stats: s),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VueCours extends StatelessWidget {
  const _VueCours({required this.stats});
  final StatsPresences stats;

  @override
  Widget build(BuildContext context) {
    final groupes = stats.parCours.length > 1 ? stats.parCours : stats.parClasse;
    final top = stats.etudiants.where((e) => e.absences > 0).take(3).toList();
    const couleurs = [AppColors.menthe, AppColors.violet, AppColors.jaune, AppColors.rose];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                  libelle: 'Présence', valeur: '${stats.tauxPourcent} %', couleur: AppColors.menthe),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                  libelle: 'Séances', valeur: '${stats.nbSeances}', couleur: AppColors.lavande),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(stats.parCours.length > 1 ? 'Présence par cours' : 'Présence par groupe',
            style: AppText.sousTitre),
        const SizedBox(height: 10),
        if (groupes.isEmpty)
          const VueVide(message: 'Pas encore de séance clôturée.')
        else
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < groupes.length && i < 4; i++)
                  PillBar(
                    valeur: groupes[i].taux,
                    libelle: '${(groupes[i].taux * 100).round()} %',
                    legende: groupes[i].libelle.split(' · ').first,
                    couleur: couleurs[i % couleurs.length],
                    hauteur: 120,
                    largeur: 54,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        AppCard(
          couleur: AppColors.rose,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plus d\'absences', style: AppText.petit),
              const SizedBox(height: 4),
              Text(
                top.isEmpty
                    ? 'Aucune absence'
                    : top.map((e) => '${Fmt.nomCourt(e.nom)} · ${e.absences}').join('  ·  '),
                style: AppText.sousTitre.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VueEtudiants extends StatelessWidget {
  const _VueEtudiants({required this.stats});
  final StatsPresences stats;

  @override
  Widget build(BuildContext context) {
    if (stats.etudiants.isEmpty) return const VueVide(message: 'Aucune donnée.');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        for (final e in stats.etudiants) ...[
          AppCard(
            rayon: 20,
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Fmt.nomCourt(e.nom), style: AppText.sousTitre.copyWith(fontSize: 13)),
                      Text(
                        '${e.presents} présences · ${e.retards} retards · ${e.absences} absences'
                        '${e.absences != e.absencesNonJustifiees ? ' (${e.absences - e.absencesNonJustifiees} justifiées)' : ''}',
                        style: AppText.petit,
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: '${(e.taux * 100).round()} %',
                  couleur: e.taux >= 0.9
                      ? AppColors.menthe
                      : (e.taux >= 0.75 ? AppColors.jaune : AppColors.rose),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
