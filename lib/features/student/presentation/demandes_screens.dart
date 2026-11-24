import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:classcheck/core/data/seance_repository.dart';
import 'package:classcheck/core/models/presence.dart';
import 'package:classcheck/core/models/seance.dart';
import 'package:classcheck/core/models/sprint2.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/student/data/demandes_repository.dart';

/// Couleur et libellé d'un statut de demande (réclamation / auto-déclaration).
StatusPill pillDemande(String statut) => switch (statut) {
      'en_attente' => const StatusPill(label: 'En attente', couleur: AppColors.jaune),
      'acceptee' || 'validee' => const StatusPill(label: 'Acceptée', couleur: AppColors.menthe),
      'refusee' => const StatusPill(label: 'Refusée', couleur: AppColors.rose),
      'transmise' => const StatusPill(label: 'Transmise', couleur: AppColors.lavande),
      _ => StatusPill(label: statut),
    };

String _titreSeance(Seance? s) =>
    s == null ? 'Séance' : '${s.coursNomCourt} · ${Fmt.jourCourt(s.date)}';

// =====================================================================
// E-AutoDeclaration
// =====================================================================

/// Séances proposées pour une auto-déclaration : 7 derniers jours et 7 prochains.
final _seancesDeclarablesProvider = FutureProvider.autoDispose<List<Seance>>((ref) {
  final j = Fmt.aujourdhui();
  return ref
      .watch(seanceRepositoryProvider)
      .seancesEntre(j.subtract(const Duration(days: 7)), j.add(const Duration(days: 7)));
});

class AutoDeclarationScreen extends ConsumerStatefulWidget {
  const AutoDeclarationScreen({super.key, this.seanceId});
  final String? seanceId;

  @override
  ConsumerState<AutoDeclarationScreen> createState() => _AutoDeclarationScreenState();
}

class _AutoDeclarationScreenState extends ConsumerState<AutoDeclarationScreen> {
  final _form = GlobalKey<FormState>();
  final _motif = TextEditingController();
  String _type = 'retard';
  late String? _seanceId = widget.seanceId;
  bool _envoi = false;

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (!_form.currentState!.validate()) return;
    if (_seanceId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Choisissez une séance.')));
      return;
    }
    setState(() => _envoi = true);
    final ok = await executerAction(
      context,
      () => ref
          .read(demandesRepositoryProvider)
          .autoDeclarer(seanceId: _seanceId!, type: _type, motif: _motif.text),
      succes: 'Déclaration envoyée à votre enseignant.',
    );
    if (!mounted) return;
    setState(() => _envoi = false);
    if (ok) {
      ref.invalidate(mesAutoDeclarationsProvider);
      _motif.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final seances = ref.watch(_seancesDeclarablesProvider);
    final mesDecl = ref.watch(mesAutoDeclarationsProvider).valueOrNull ?? const [];
    final dejaDeclarees = {for (final d in mesDecl) d.seanceId};
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Auto-déclaration', repli: '/etudiant'),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    PillTabs<String>(
                      etirer: true,
                      options: const [('retard', 'Retard'), ('absence_justifiee', 'Absence justifiée')],
                      valeur: _type,
                      onChanged: (t) => setState(() => _type = t),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text('Séance', style: AppText.petit),
                    ),
                    AsyncValueView<List<Seance>>(
                      valeur: seances,
                      onReessayer: () => ref.invalidate(_seancesDeclarablesProvider),
                      donnees: (liste) {
                        final choix = liste.where((s) => !dejaDeclarees.contains(s.id)).toList();
                        if (choix.isEmpty) {
                          return const VueVide(message: 'Aucune séance récente à déclarer.');
                        }
                        if (_seanceId != null && !choix.any((s) => s.id == _seanceId)) {
                          _seanceId = null;
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: AppColors.blanc,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _seanceId,
                              hint: Text('Choisir une séance', style: AppText.secondaire),
                              items: [
                                for (final s in choix)
                                  DropdownMenuItem(
                                    value: s.id,
                                    child: Text('${_titreSeance(s)} · ${Fmt.heureSql(s.heureDebut)}',
                                        style: AppText.corps),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _seanceId = v),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    PillField(
                      libelle: 'Motif',
                      controller: _motif,
                      lignes: 3,
                      indice: _type == 'retard' ? 'Ex. : problème de transport' : 'Ex. : rendez-vous médical',
                      validator: (v) => (v ?? '').trim().length < 3 ? 'Le motif est obligatoire' : null,
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      couleur: AppColors.jaune,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Statut', style: AppText.petit),
                                Text('En attente', style: AppText.sousTitre),
                                Text('Votre enseignant doit valider cette déclaration.',
                                    style: AppText.petit),
                              ],
                            ),
                          ),
                          const Icon(Icons.hourglass_top_rounded),
                        ],
                      ),
                    ),
                    if (mesDecl.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Mes déclarations', style: AppText.sousTitre),
                      const SizedBox(height: 8),
                      for (final d in mesDecl.take(5)) ...[
                        AppCard(
                          rayon: 20,
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${d.libelleType} · ${_titreSeance(d.seance)}',
                                        style: AppText.sousTitre.copyWith(fontSize: 13)),
                                    Text(d.motif, style: AppText.petit, maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              pillDemande(d.statut),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PillButton(label: 'Envoyer', chargement: _envoi, onPressed: _envoyer),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// E-Reclamation (nouvelle réclamation avec justificatif)
// =====================================================================

class NouvelleReclamationScreen extends ConsumerStatefulWidget {
  const NouvelleReclamationScreen({super.key, required this.presence});
  final Presence presence;

  @override
  ConsumerState<NouvelleReclamationScreen> createState() => _NouvelleReclamationScreenState();
}

class _NouvelleReclamationScreenState extends ConsumerState<NouvelleReclamationScreen> {
  final _form = GlobalKey<FormState>();
  final _motif = TextEditingController();
  Uint8List? _photo;
  String _extension = 'jpg';
  bool _envoi = false;

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  Future<void> _choisirPhoto(ImageSource source) async {
    final fichier = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    if (fichier == null) return;
    final octets = await fichier.readAsBytes();
    if (octets.length > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Fichier trop lourd (5 Mo maximum).')));
      return;
    }
    setState(() {
      _photo = octets;
      _extension = fichier.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    });
  }

  Future<void> _envoyer() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _envoi = true);
    final ok = await executerAction(
      context,
      () => ref.read(demandesRepositoryProvider).creerReclamation(
            presenceId: widget.presence.id,
            motif: _motif.text,
            justificatif: _photo,
            extension: _extension,
          ),
      succes: 'Réclamation envoyée.',
    );
    if (!mounted) return;
    setState(() => _envoi = false);
    if (ok) {
      ref.invalidate(mesReclamationsProvider);
      context.pushReplacement('/etudiant/reclamations');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.presence.seance;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Nouvelle réclamation', repli: '/etudiant/assiduite'),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    AppCard(
                      couleur: AppColors.rose,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Absence contestée', style: AppText.petit),
                                Text(_titreSeance(s), style: AppText.sousTitre),
                                if (s != null) Text(s.plage, style: AppText.petit),
                              ],
                            ),
                          ),
                          StatusPill.presence(widget.presence.statut),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    PillField(
                      libelle: 'Motif',
                      controller: _motif,
                      lignes: 4,
                      indice: 'Expliquez la raison de votre absence',
                      validator: (v) => (v ?? '').trim().length < 5 ? 'Décrivez le motif' : null,
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text('Justificatif', style: AppText.petit),
                    ),
                    AppCard(
                      couleur: AppColors.lavande,
                      child: Column(
                        children: [
                          if (_photo != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.memory(_photo!, height: 160, fit: BoxFit.cover),
                            )
                          else ...[
                            const Icon(Icons.description_outlined, size: 36),
                            const SizedBox(height: 6),
                            Text('Photo du certificat ou du document', style: AppText.petit),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PillButton.petit(
                                label: _photo == null ? 'Ajouter une photo' : 'Changer',
                                icone: Icons.photo_camera_outlined,
                                onPressed: () => _choisirPhoto(ImageSource.camera),
                              ),
                              const SizedBox(width: 8),
                              PillButton.petit(
                                label: 'Galerie',
                                variant: PillVariant.clair,
                                icone: Icons.photo_library_outlined,
                                onPressed: () => _choisirPhoto(ImageSource.gallery),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PillButton(
                label: 'Envoyer la réclamation',
                chargement: _envoi,
                onPressed: _envoyer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// E-Reclamations (suivi)
// =====================================================================

enum _FiltreRecl { toutes, enCours, closes }

class MesReclamationsScreen extends ConsumerStatefulWidget {
  const MesReclamationsScreen({super.key});

  @override
  ConsumerState<MesReclamationsScreen> createState() => _MesReclamationsScreenState();
}

class _MesReclamationsScreenState extends ConsumerState<MesReclamationsScreen> {
  _FiltreRecl _filtre = _FiltreRecl.toutes;

  Future<void> _recours(Reclamation r) async {
    final motif = await demanderMotif(context,
        titre: 'Recours auprès du directeur', libelleBouton: 'Transmettre au directeur');
    if (motif == null || !mounted) return;
    final ok = await executerAction(
      context,
      () => ref.read(demandesRepositoryProvider).contester(r.id, motif),
      succes: 'Recours transmis au directeur.',
    );
    if (ok) ref.invalidate(mesReclamationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final reclamations = ref.watch(mesReclamationsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Mes réclamations', repli: '/etudiant'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: PillTabs<_FiltreRecl>(
                options: const [
                  (_FiltreRecl.toutes, 'Toutes'),
                  (_FiltreRecl.enCours, 'En cours'),
                  (_FiltreRecl.closes, 'Closes'),
                ],
                valeur: _filtre,
                onChanged: (f) => setState(() => _filtre = f),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(mesReclamationsProvider),
                child: AsyncValueView<List<Reclamation>>(
                  valeur: reclamations,
                  onReessayer: () => ref.invalidate(mesReclamationsProvider),
                  donnees: (toutes) {
                    final liste = toutes.where((r) => switch (_filtre) {
                          _FiltreRecl.toutes => true,
                          _FiltreRecl.enCours => r.enCours,
                          _FiltreRecl.closes => !r.enCours,
                        }).toList();
                    if (liste.isEmpty) {
                      return ListView(children: const [
                        VueVide(message: 'Aucune réclamation.', icone: Icons.inbox_outlined),
                      ]);
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        for (final r in liste) ...[
                          _CarteReclamation(reclamation: r, onRecours: () => _recours(r)),
                          const SizedBox(height: 10),
                        ],
                      ],
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

class _CarteReclamation extends StatelessWidget {
  const _CarteReclamation({required this.reclamation, required this.onRecours});
  final Reclamation reclamation;
  final VoidCallback onRecours;

  @override
  Widget build(BuildContext context) {
    final r = reclamation;
    final sous = switch (r.statut) {
      'en_attente' => 'Envoyée le ${Fmt.jourCourt(r.creeA)}',
      'transmise' => 'Recours en cours · le directeur examine votre dossier',
      _ => 'Traitée par ${r.decisionParNom ?? 'l\'établissement'}',
    };
    final peutRecours = r.recoursPossible;
    return AppCard(
      rayon: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_titreSeance(r.seance), style: AppText.sousTitre.copyWith(fontSize: 13)),
              ),
              pillDemande(r.statut),
            ],
          ),
          const SizedBox(height: 2),
          Text(sous, style: AppText.petit),
          if (r.commentaireDecision != null && !r.enCours) ...[
            const SizedBox(height: 6),
            Text('« ${r.commentaireDecision} »', style: AppText.secondaire),
          ],
          if (peutRecours) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: PillButton.petit(label: 'Faire un recours', onPressed: onRecours),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// E-Notifications
// =====================================================================

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Ouvrir l'écran marque tout comme lu (la liste reste affichée).
    Future.microtask(() => ref.read(demandesRepositoryProvider).toutMarquerLu().catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    final notifs = ref.watch(notificationsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Notifications', repli: '/etudiant'),
            Expanded(
              child: AsyncValueView<List<NotificationApp>>(
                valeur: notifs,
                onReessayer: () => ref.invalidate(notificationsProvider),
                donnees: (liste) {
                  final tri = [...liste]..sort((a, b) => b.creeA.compareTo(a.creeA));
                  if (tri.isEmpty) {
                    return const VueVide(
                        message: 'Aucune notification.', icone: Icons.notifications_none_rounded);
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      for (final n in tri) ...[
                        AppCard(
                          rayon: 22,
                          couleur: _couleur(n),
                          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(_icone(n), size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n.titre, style: AppText.sousTitre.copyWith(fontSize: 13)),
                                    Text(n.message, style: AppText.petit),
                                    const SizedBox(height: 4),
                                    Text('${Fmt.jourCourt(n.creeA)} · ${Fmt.heure(n.creeA)}',
                                        style: AppText.petit.copyWith(fontSize: 10)),
                                  ],
                                ),
                              ),
                              if (!n.lu)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: AppColors.bleu, shape: BoxShape.circle),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _couleur(NotificationApp n) => switch (n.type) {
        'seuil' => AppColors.jaune,
        'reclamation' when n.titre.contains('acceptée') => AppColors.menthe,
        'reclamation' when n.titre.contains('refusée') => AppColors.rose,
        'reclamation' => AppColors.lavande,
        _ => AppColors.blanc,
      };

  static IconData _icone(NotificationApp n) => switch (n.type) {
        'seuil' => Icons.warning_amber_rounded,
        'reclamation' => Icons.mark_email_read_outlined,
        'auto_declaration' => Icons.how_to_reg_outlined,
        _ => Icons.notifications_none_rounded,
      };
}
