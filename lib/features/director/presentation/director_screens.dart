import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:classcheck/core/data/seance_repository.dart';
import 'package:classcheck/core/data/suivi_repository.dart';
import 'package:classcheck/core/models/sprint2.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/utils/validateurs.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/auth/data/auth_repository.dart';
import 'package:classcheck/features/auth/domain/profil.dart';
import 'package:classcheck/features/director/data/director_repository.dart';
import 'package:classcheck/features/director/domain/export_stats.dart';
import 'package:classcheck/features/director/presentation/directeur_tableau_screen.dart';

// =====================================================================
// D-Risque : étudiants à risque
// =====================================================================

class EtudiantsARisqueScreen extends ConsumerWidget {
  const EtudiantsARisqueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final risque = ref.watch(etudiantsARisqueProvider);
    final seuil = ref.watch(reglesProvider).valueOrNull?.seuilExclusion ?? 5;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Étudiants à risque', repli: '/directeur'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(etudiantsARisqueProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    AppCard(
                      couleur: AppColors.lavande,
                      child: Row(
                        children: [
                          Expanded(child: Text('Seuil d\'exclusion', style: AppText.sousTitre)),
                          StatusPill(label: '$seuil absences'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AsyncValueView<List<EtudiantARisque>>(
                      valeur: risque,
                      onReessayer: () => ref.invalidate(etudiantsARisqueProvider),
                      donnees: (liste) => liste.isEmpty
                          ? const VueVide(message: 'Aucun étudiant à risque.', icone: Icons.verified_outlined)
                          : Column(
                              children: [
                                for (final r in liste) ...[
                                  AppCard(
                                    rayon: 22,
                                    couleur: r.depasse ? AppColors.rose : AppColors.jaune,
                                    padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(Fmt.nomCourt(r.nom), style: AppText.sousTitre),
                                              Text('${r.classe} · ${r.cours}', style: AppText.petit),
                                            ],
                                          ),
                                        ),
                                        StatusPill(label: '${r.absences} abs.'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ),
                    ),
                    Text('Absences non justifiées, par cours. Rouge : seuil atteint.',
                        style: AppText.petit, textAlign: TextAlign.center),
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

// =====================================================================
// D-Audit : journal d'audit
// =====================================================================

enum _FiltreAudit { tout, corrections, decisions }

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  _FiltreAudit _filtre = _FiltreAudit.tout;

  String _quand(DateTime d) {
    final aujourdhui = Fmt.aujourdhui();
    if (Fmt.memeJour(d, aujourdhui)) return Fmt.heure(d);
    if (Fmt.memeJour(d, aujourdhui.subtract(const Duration(days: 1)))) return 'Hier';
    return Fmt.jourCourt(d);
  }

  String _detail(EntreeAudit e, Map<String, String> noms) {
    final d = e.details;
    String nom(Object? id) => Fmt.nomCourt(noms[id] ?? 'étudiant');
    String statut(Object? s) => switch (s) {
          'present' => 'Présent',
          'absent' => 'Absent',
          'retard' => 'Retard',
          'acceptee' => 'Acceptée',
          'refusee' => 'Refusée',
          'transmise' => 'Transmise',
          'validee' => 'Validée',
          'en_attente' => 'En attente',
          null => '—',
          _ => '$s',
        };
    final parties = <String>[e.acteurNom ?? 'Système'];
    if (d['etudiant_id'] != null) parties.add(nom(d['etudiant_id']));
    if (d.containsKey('nouveau')) parties.add('${statut(d['ancien'])} vers ${statut(d['nouveau'])}');
    if (d['erreur'] != null) parties.add('${d['erreur']}');
    if (d['distance'] != null) parties.add('distance ${d['distance']}');
    final motif = e.motif == null ? '' : ' · Motif : ${e.motif}';
    return parties.join(' · ') + motif;
  }

  @override
  Widget build(BuildContext context) {
    final audit = ref.watch(auditProvider);
    final noms = {for (final p in ref.watch(comptesProvider).valueOrNull ?? const <Profil>[]) p.id: p.nom};
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Journal d\'audit', repli: '/directeur'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: PillTabs<_FiltreAudit>(
                options: const [
                  (_FiltreAudit.tout, 'Tout'),
                  (_FiltreAudit.corrections, 'Corrections'),
                  (_FiltreAudit.decisions, 'Décisions'),
                ],
                valeur: _filtre,
                onChanged: (f) => setState(() => _filtre = f),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(auditProvider),
                child: AsyncValueView<List<EntreeAudit>>(
                  valeur: audit,
                  onReessayer: () => ref.invalidate(auditProvider),
                  donnees: (toutes) {
                    final l = toutes.where((e) => switch (_filtre) {
                          _FiltreAudit.tout => true,
                          _FiltreAudit.corrections => e.estCorrection,
                          _FiltreAudit.decisions => e.estDecision,
                        }).toList();
                    if (l.isEmpty) {
                      return ListView(children: const [VueVide(message: 'Aucune entrée.')]);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: l.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final e = l[i];
                        return AppCard(
                          rayon: 20,
                          couleur: e.estCorrection
                              ? AppColors.jaune
                              : (e.estDecision ? AppColors.lavande : AppColors.blanc),
                          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(e.libelle, style: AppText.sousTitre.copyWith(fontSize: 13)),
                                  ),
                                  Text(_quand(e.creeA), style: AppText.petit),
                                ],
                              ),
                              Text(_detail(e, noms), style: AppText.petit),
                            ],
                          ),
                        );
                      },
                    );
                  },
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
// D-Regles : règles de l'établissement
// =====================================================================

class ReglesScreen extends ConsumerStatefulWidget {
  const ReglesScreen({super.key});

  @override
  ConsumerState<ReglesScreen> createState() => _ReglesScreenState();
}

class _ReglesScreenState extends ConsumerState<ReglesScreen> {
  Regles? _r;
  bool _envoi = false;

  Future<void> _enregistrer() async {
    setState(() => _envoi = true);
    final ok = await executerAction(
      context,
      () => ref.read(directorRepositoryProvider).enregistrerRegles(_r!),
      succes: 'Règles enregistrées (tracé dans l\'audit).',
    );
    if (!mounted) return;
    setState(() => _envoi = false);
    if (ok) ref.invalidate(reglesProvider);
  }

  Widget _compteur(String libelle, int valeur, int min, int max, int pas, ValueChanged<int> f) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
      child: Row(
        children: [
          Expanded(child: Text(libelle, style: AppText.corps)),
          RoundIconButton(
            icone: Icons.remove,
            taille: 36,
            couleur: AppColors.puce,
            onPressed: valeur - pas >= min ? () => f(valeur - pas) : null,
          ),
          SizedBox(
            width: 44,
            child: Text('$valeur', textAlign: TextAlign.center, style: AppText.sousTitre),
          ),
          RoundIconButton(
            icone: Icons.add,
            taille: 36,
            couleur: AppColors.puce,
            onPressed: valeur + pas <= max ? () => f(valeur + pas) : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regles = ref.watch(reglesProvider);
    _r ??= regles.valueOrNull;
    final r = _r;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Règles de l\'établissement', repli: '/directeur'),
            Expanded(
              child: r == null
                  ? const Chargement()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        _compteur('Seuil d\'exclusion (absences)', r.seuilExclusion, 1, 30, 1,
                            (v) => setState(() => _r = r.copier(seuilExclusion: v))),
                        const SizedBox(height: 10),
                        _compteur('Fenêtre de pointage (minutes)', r.fenetrePointage, 5, 60, 5,
                            (v) => setState(() => _r = r.copier(fenetrePointage: v))),
                        const SizedBox(height: 10),
                        _compteur('Renouvellement du QR (secondes)', r.renouvellementQr, 10, 120, 5,
                            (v) => setState(() => _r = r.copier(renouvellementQr: v))),
                        const SizedBox(height: 10),
                        AppCard(
                          couleur: AppColors.menthe,
                          padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Vérification du visage', style: AppText.sousTitre.copyWith(fontSize: 13)),
                                    Text('Obligatoire au pointage', style: AppText.petit),
                                  ],
                                ),
                              ),
                              Switch(
                                value: r.visageObligatoire,
                                onChanged: (v) => setState(() => _r = r.copier(visageObligatoire: v)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text('Reconnaissance faciale (avancé)', style: AppText.sousTitre),
                        const SizedBox(height: 8),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text('Seuil de distance', style: AppText.corps)),
                                  Text(r.seuilVisage.toStringAsFixed(2), style: AppText.sousTitre),
                                ],
                              ),
                              Slider(
                                value: r.seuilVisage.clamp(0.6, 1.3),
                                min: 0.6,
                                max: 1.3,
                                divisions: 14,
                                onChanged: (v) => setState(() => _r = r.copier(seuilVisage: v)),
                              ),
                              Text('Plus bas = plus strict (moins de fraudes, plus de refus).',
                                  style: AppText.petit),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _compteur('Captures devant reconnaître le visage (sur 5)', r.votesVisage, 1, 5, 1,
                            (v) => setState(() => _r = r.copier(votesVisage: v))),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PillButton(
                label: 'Enregistrer les règles',
                chargement: _envoi,
                onPressed: r == null ? null : _enregistrer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// D-Gestion : comptes et emplois du temps
// =====================================================================

class GestionScreen extends ConsumerStatefulWidget {
  const GestionScreen({super.key});

  @override
  ConsumerState<GestionScreen> createState() => _GestionScreenState();
}

class _GestionScreenState extends ConsumerState<GestionScreen> {
  bool _emplois = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Gestion', repli: '/directeur'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: PillTabs<bool>(
                etirer: true,
                options: const [(false, 'Comptes'), (true, 'Emplois du temps')],
                valeur: _emplois,
                onChanged: (v) => setState(() => _emplois = v),
              ),
            ),
            Expanded(child: _emplois ? const _EmploisDuTemps() : const _Comptes()),
          ],
        ),
      ),
    );
  }
}

class _Comptes extends ConsumerWidget {
  const _Comptes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comptes = ref.watch(comptesProvider);
    final moi = ref.watch(profilProvider).valueOrNull?.id;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(comptesProvider),
            child: AsyncValueView<List<Profil>>(
              valeur: comptes,
              onReessayer: () => ref.invalidate(comptesProvider),
              donnees: (liste) {
                // Comptes inactifs (inscriptions à valider) en premier.
                final tri = [...liste]..sort((a, b) => (a.actif ? 1 : 0) - (b.actif ? 1 : 0));
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    for (final p in tri) ...[
                      AppCard(
                        rayon: 22,
                        onTap: p.id == moi ? null : () => _modifier(context, ref, p),
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.nom, style: AppText.sousTitre.copyWith(fontSize: 13)),
                                  Text(p.sousTitre.isEmpty ? p.email : '${p.role.libelle}${p.classe == null ? '' : ' · ${p.classe}'}',
                                      style: AppText.petit),
                                ],
                              ),
                            ),
                            StatusPill(
                              label: p.actif ? 'Actif' : 'Inactif',
                              couleur: p.actif ? AppColors.menthe : AppColors.jaune,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: PillButton(
            label: 'Ajouter un compte',
            icone: Icons.person_add_alt_1_outlined,
            onPressed: () => _ajouter(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _modifier(BuildContext context, WidgetRef ref, Profil p) async {
    var role = p.role;
    var actif = p.actif;
    final classe = TextEditingController(text: p.classe ?? '');
    final motif = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.fond,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(p.nom, style: AppText.entete),
              Text(p.email, style: AppText.petit),
              const SizedBox(height: 14),
              PillTabs<Role>(
                etirer: true,
                options: [for (final r in Role.values) (r, r.libelle)],
                valeur: role,
                onChanged: (r) => setS(() => role = r),
              ),
              if (role == Role.etudiant) ...[
                const SizedBox(height: 12),
                PillField(libelle: 'Classe', controller: classe, indice: 'DSI 2'),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Compte actif', style: AppText.corps),
                value: actif,
                onChanged: (v) => setS(() => actif = v),
              ),
              PillField(libelle: 'Motif (journal d\'audit)', controller: motif),
              const SizedBox(height: 14),
              PillButton(label: 'Enregistrer', onPressed: () => Navigator.pop(ctx, true)),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final reussi = await executerAction(
      context,
      () => ref.read(directorRepositoryProvider).gererCompte(
            p.id,
            role: role,
            classe: role == Role.etudiant ? Fmt.normaliserClasse(classe.text) : null,
            actif: actif,
            motif: motif.text,
          ),
      succes: 'Compte mis à jour.',
    );
    if (reussi) ref.invalidate(comptesProvider);
  }

  Future<void> _ajouter(BuildContext context, WidgetRef ref) async {
    final cle = GlobalKey<FormState>();
    final nom = TextEditingController();
    final email = TextEditingController();
    final classe = TextEditingController();
    final mdp = TextEditingController();
    var role = Role.etudiant;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.fond,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Form(
            key: cle,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Nouveau compte', style: AppText.entete),
                  const SizedBox(height: 12),
                  PillTabs<Role>(
                    etirer: true,
                    options: [for (final r in Role.values) (r, r.libelle)],
                    valeur: role,
                    onChanged: (r) => setS(() => role = r),
                  ),
                  const SizedBox(height: 10),
                  PillField(libelle: 'Nom complet', controller: nom,
                      validator: (v) => validerRequis(v, 'Le nom')),
                  const SizedBox(height: 10),
                  PillField(libelle: 'E-mail', controller: email, clavier: TextInputType.emailAddress,
                      validator: validerEmail),
                  if (role == Role.etudiant) ...[
                    const SizedBox(height: 10),
                    PillField(libelle: 'Classe', controller: classe, indice: 'DSI 2', validator: validerClasse),
                  ],
                  const SizedBox(height: 10),
                  PillField(libelle: 'Mot de passe provisoire', controller: mdp, motDePasse: true,
                      validator: validerMotDePasse),
                  const SizedBox(height: 14),
                  PillButton(
                    label: 'Créer le compte',
                    onPressed: () {
                      if (cle.currentState!.validate()) Navigator.pop(ctx, true);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final reussi = await executerAction(
      context,
      () => ref.read(directorRepositoryProvider).creerCompte(
            email: email.text,
            nom: nom.text,
            role: role,
            classe: role == Role.etudiant ? Fmt.normaliserClasse(classe.text) : null,
            motDePasse: mdp.text,
          ),
      succes: 'Compte créé. Communiquez le mot de passe provisoire à son titulaire.',
    );
    if (reussi) ref.invalidate(comptesProvider);
  }
}

class _EmploisDuTemps extends ConsumerWidget {
  const _EmploisDuTemps();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cours = ref.watch(coursProvider);
    return Column(
      children: [
        Expanded(
          child: AsyncValueView<List<Cours>>(
            valeur: cours,
            onReessayer: () => ref.invalidate(coursProvider),
            donnees: (liste) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (liste.isEmpty) const VueVide(message: 'Aucun cours.'),
                for (final c in liste) ...[
                  AppCard(
                    rayon: 22,
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${c.nomCourt} · ${c.classe}', style: AppText.sousTitre.copyWith(fontSize: 13)),
                              Text('${c.enseignantNom ?? 'Sans enseignant'} · ${c.salle ?? '—'}',
                                  style: AppText.petit),
                            ],
                          ),
                        ),
                        PillButton.petit(label: 'Planifier', onPressed: () => _planifier(context, ref, c)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: PillButton(
            label: 'Nouveau cours',
            icone: Icons.add,
            onPressed: () => _nouveauCours(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _planifier(BuildContext context, WidgetRef ref, Cours c) async {
    var date = Fmt.aujourdhui();
    var debut = const TimeOfDay(hour: 10, minute: 0);
    var fin = const TimeOfDay(hour: 12, minute: 0);
    var semaines = 4;
    final salle = TextEditingController(text: c.salle ?? '');
    String h(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.fond,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Planifier · ${c.nomCourt} ${c.classe}', style: AppText.entete),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: '${Fmt.joursCourts[date.weekday - 1]} ${Fmt.jourCourt(date)}',
                      variant: PillVariant.clair,
                      icone: Icons.event,
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: Fmt.aujourdhui().subtract(const Duration(days: 30)),
                          lastDate: Fmt.aujourdhui().add(const Duration(days: 365)),
                        );
                        if (d != null) setS(() => date = d);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Début ${h(debut)}',
                      variant: PillVariant.clair,
                      onPressed: () async {
                        final t = await showTimePicker(context: ctx, initialTime: debut);
                        if (t != null) setS(() => debut = t);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PillButton(
                      label: 'Fin ${h(fin)}',
                      variant: PillVariant.clair,
                      onPressed: () async {
                        final t = await showTimePicker(context: ctx, initialTime: fin);
                        if (t != null) setS(() => fin = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              PillField(libelle: 'Salle', controller: salle),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text('Répéter chaque semaine', style: AppText.corps)),
                  RoundIconButton(
                    icone: Icons.remove,
                    taille: 36,
                    couleur: AppColors.puce,
                    onPressed: semaines > 1 ? () => setS(() => semaines--) : null,
                  ),
                  SizedBox(width: 60, child: Text('$semaines sem.', textAlign: TextAlign.center)),
                  RoundIconButton(
                    icone: Icons.add,
                    taille: 36,
                    couleur: AppColors.puce,
                    onPressed: semaines < 30 ? () => setS(() => semaines++) : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              PillButton(label: 'Créer les séances', onPressed: () => Navigator.pop(ctx, true)),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await executerAction(
      context,
      () async {
        final n = await ref.read(directorRepositoryProvider).planifierSeances(
              coursId: c.id,
              premiere: date,
              heureDebut: h(debut),
              heureFin: h(fin),
              salle: salle.text,
              semaines: semaines,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n séance(s) créée(s).')));
        }
      },
    );
  }

  Future<void> _nouveauCours(BuildContext context, WidgetRef ref) async {
    final cle = GlobalKey<FormState>();
    final nom = TextEditingController();
    final court = TextEditingController();
    final classe = TextEditingController();
    final salle = TextEditingController();
    String? enseignant;
    final List<Profil> tous =
        ref.read(comptesProvider).valueOrNull ?? await ref.read(directorRepositoryProvider).comptes();
    final enseignants = tous.where((p) => p.role == Role.enseignant && p.actif).toList();
    if (!context.mounted) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.fond,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Form(
            key: cle,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Nouveau cours', style: AppText.entete),
                  const SizedBox(height: 12),
                  PillField(libelle: 'Intitulé', controller: nom, validator: (v) => validerRequis(v, 'L\'intitulé')),
                  const SizedBox(height: 10),
                  PillField(libelle: 'Nom court', controller: court, indice: 'Flutter'),
                  const SizedBox(height: 10),
                  PillField(libelle: 'Classe', controller: classe, indice: 'DSI 2', validator: validerClasse),
                  const SizedBox(height: 10),
                  PillField(libelle: 'Salle', controller: salle),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(color: AppColors.blanc, borderRadius: BorderRadius.circular(26)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: enseignant,
                        hint: const Text('Enseignant'),
                        items: [
                          for (final e in enseignants) DropdownMenuItem(value: e.id, child: Text(e.nom)),
                        ],
                        onChanged: (v) => setS(() => enseignant = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  PillButton(
                    label: 'Créer le cours',
                    onPressed: () {
                      if (cle.currentState!.validate()) Navigator.pop(ctx, true);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final reussi = await executerAction(
      context,
      () => ref.read(directorRepositoryProvider).creerCours(
            nom: nom.text,
            nomCourt: court.text,
            classe: Fmt.normaliserClasse(classe.text),
            salle: salle.text.trim().isEmpty ? null : salle.text.trim(),
            enseignantId: enseignant,
          ),
      succes: 'Cours créé. Planifiez maintenant ses séances.',
    );
    if (reussi) ref.invalidate(coursProvider);
  }
}

// =====================================================================
// D-Export : export PDF / CSV
// =====================================================================

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  Periode _periode = Periode.mois;
  bool _pdf = true;
  bool _envoi = false;

  Future<void> _exporter() async {
    setState(() => _envoi = true);
    await executerAction(context, () async {
      final suivi = ref.read(suiviRepositoryProvider);
      final stats = await suivi.stats(_periode.filtre());
      final risque = await suivi.etudiantsARisque();
      final dossier = await getTemporaryDirectory();
      final horodatage = Fmt.dateSql(DateTime.now());
      final File fichier;
      if (_pdf) {
        fichier = File('${dossier.path}/classcheck_stats_$horodatage.pdf');
        await fichier.writeAsBytes(
            await ExportStats.pdf(stats, periode: _periode.libelle, aRisque: risque));
      } else {
        fichier = File('${dossier.path}/classcheck_stats_$horodatage.csv');
        await fichier.writeAsString(ExportStats.csv(stats, periode: _periode.libelle), encoding: utf8);
      }
      await SharePlus.instance.share(ShareParams(
        files: [XFile(fichier.path, mimeType: _pdf ? 'application/pdf' : 'text/csv')],
        subject: 'ClassCheck — statistiques (${_periode.libelle})',
      ));
    });
    if (mounted) setState(() => _envoi = false);
  }

  Widget _format(bool pdf, String titre, String detail, Color couleur) {
    final choisi = _pdf == pdf;
    return AppCard(
      couleur: couleur,
      onTap: () => setState(() => _pdf = pdf),
      bordure: choisi ? Border.all(color: AppColors.texte, width: 1.5) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: AppText.sousTitre),
                Text(detail, style: AppText.petit),
              ],
            ),
          ),
          StatusPill(label: choisi ? 'Choisi' : 'Choisir', couleur: choisi ? AppColors.texte : AppColors.blanc,
              couleurTexte: choisi ? AppColors.blanc : AppColors.texte),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Export des statistiques', repli: '/directeur'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('Période', style: AppText.petit),
                  ),
                  PillTabs<Periode>(
                    etirer: true,
                    options: const [
                      (Periode.semaine, 'Semaine'),
                      (Periode.mois, 'Mois'),
                      (Periode.semestre, 'Semestre'),
                    ],
                    valeur: _periode,
                    onChanged: (p) => setState(() => _periode = p),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('Format', style: AppText.petit),
                  ),
                  _format(true, 'PDF', 'Rapport mis en page, prêt à imprimer', AppColors.lavande),
                  const SizedBox(height: 10),
                  _format(false, 'CSV', 'Données brutes pour Excel', AppColors.menthe),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PillButton(label: 'Exporter', chargement: _envoi, onPressed: _exporter),
            ),
          ],
        ),
      ),
    );
  }
}
