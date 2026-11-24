import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:classcheck/core/data/seance_repository.dart';
import 'package:classcheck/core/models/presence.dart';
import 'package:classcheck/core/models/qr_seance.dart';
import 'package:classcheck/core/models/seance.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/utils/messages_erreur.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/teacher/data/teacher_repository.dart';
import 'package:classcheck/features/teacher/presentation/cloture_action.dart';

/// Maquette « Enseignant-QR » : QR renouvelé automatiquement + présents en direct.
class QrSeanceScreen extends ConsumerStatefulWidget {
  const QrSeanceScreen({super.key, required this.seanceId});
  final String seanceId;

  @override
  ConsumerState<QrSeanceScreen> createState() => _QrSeanceScreenState();
}

class _QrSeanceScreenState extends ConsumerState<QrSeanceScreen> {
  QrToken? _qr;
  String? _erreur;
  bool _renouvellement = false;
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    _renouveler();
    _minuteur = Timer.periodic(const Duration(milliseconds: 500), (_) => _tic());
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  void _tic() {
    if (!mounted) return;
    final qr = _qr;
    if (qr != null && !qr.estValide() && !_renouvellement && _erreur == null) {
      _renouveler();
    }
    setState(() {});
  }

  Future<void> _renouveler() async {
    _renouvellement = true;
    try {
      final qr = await ref.read(teacherRepositoryProvider).genererQr(widget.seanceId);
      if (!mounted) return;
      setState(() {
        _qr = qr;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = messageErreur(e));
    } finally {
      _renouvellement = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final seance = ref.watch(seanceProvider(widget.seanceId));
    final s = seance.valueOrNull;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Séance en cours', repli: '/enseignant'),
            if (s != null)
              Text('${s.coursNomCourt} · ${s.plage} · ${s.salle}', style: AppText.petit),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: _erreur != null
                        ? _FenetreTerminee(message: _erreur!, onReessayer: _renouveler)
                        : _BlocQr(qr: _qr),
                  ),
                  const SizedBox(height: 12),
                  if (s != null) _ApercuPresents(seance: s),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PillButton(
                label: 'Clôturer la séance',
                onPressed: s == null ? null : () => cloturerSeance(context, ref, s),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlocQr extends StatelessWidget {
  const _BlocQr({required this.qr});
  final QrToken? qr;

  @override
  Widget build(BuildContext context) {
    final q = qr;
    return Column(
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: q == null
              ? const Center(child: CircularProgressIndicator())
              : QrImageView(
                  data: q.contenu,
                  version: QrVersions.auto,
                  size: 220,
                  gapless: true,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.texte),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.texte,
                  ),
                ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Text('Nouveau code dans', style: AppText.petit)),
            StatusPill(
              label: Fmt.compteARebours(q?.secondesRestantes() ?? 0),
              couleur: AppColors.lavande,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ProgressPill(
          valeur: q?.progression() ?? 0,
          couleur: AppColors.violet,
          fond: AppColors.fond,
        ),
      ],
    );
  }
}

class _FenetreTerminee extends StatelessWidget {
  const _FenetreTerminee({required this.message, required this.onReessayer});
  final String message;
  final VoidCallback onReessayer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.timer_off_outlined, size: 48, color: AppColors.texteSecondaire),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: AppText.corps),
        const SizedBox(height: 6),
        Text(
          'Plus aucun étudiant ne peut pointer. Clôturez la séance pour enregistrer les absences.',
          textAlign: TextAlign.center,
          style: AppText.petit,
        ),
        const SizedBox(height: 12),
        PillButton.petit(label: 'Réessayer', onPressed: onReessayer),
      ],
    );
  }
}

/// Carte menthe « Présents en direct 24 / 30 » avec les derniers pointages.
class _ApercuPresents extends ConsumerWidget {
  const _ApercuPresents({required this.seance});
  final Seance seance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presences = ref.watch(presencesEnDirectProvider(seance.id)).valueOrNull ?? const <Presence>[];
    final etudiants = ref.watch(etudiantsClasseProvider(seance.classe)).valueOrNull ?? const [];
    final noms = {for (final e in etudiants) e.id: e.nom};
    final presents = presences.where((p) => p.estPresent).toList()
      ..sort((a, b) => (b.pointeA ?? DateTime(2000)).compareTo(a.pointeA ?? DateTime(2000)));

    return AppCard(
      couleur: AppColors.menthe,
      onTap: () => context.push('/enseignant/seance/${seance.id}/presents'),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Présents en direct', style: AppText.sousTitre)),
              Text('${presents.length} / ${etudiants.length}', style: AppText.titre),
            ],
          ),
          const SizedBox(height: 10),
          if (presents.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('En attente des premiers pointages…', style: AppText.petit),
            ),
          for (final p in presents.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(Fmt.nomCourt(noms[p.etudiantId] ?? 'Étudiant'),
                        style: AppText.corps),
                  ),
                  StatusPill(
                    label: '${p.pointeA == null ? '' : Fmt.heure(p.pointeA!)} · '
                        '${p.methode == 'qr_visage' ? 'visage' : p.libelleMethode}',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
