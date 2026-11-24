import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/utils/messages_erreur.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/face/data/face_camera.dart';
import 'package:classcheck/features/face/data/face_repository.dart';
import 'package:classcheck/features/face/domain/liveness.dart';
import 'package:classcheck/features/face/presentation/widgets/face_oval.dart';
import 'package:classcheck/features/student/data/student_repository.dart';
import 'package:classcheck/features/student/domain/pointage.dart';

/// Maquette « Etudiant-Selfie » — étape 2 : vivacité + reconnaissance.
class SelfieScreen extends ConsumerStatefulWidget {
  const SelfieScreen({super.key, required this.ticket});
  final TicketPointage ticket;

  @override
  ConsumerState<SelfieScreen> createState() => _SelfieScreenState();
}

class _SelfieScreenState extends ConsumerState<SelfieScreen> {
  late final FaceCamera _camera = FaceCamera(onVisages: _surVisages);
  // Défi tiré au hasard à chaque pointage (clignement ou rotation de la tête).
  final LivenessDetector _vivacite = LivenessDetector(defi: DefiVivacite.auHasard());
  int? _idSuivi;
  bool _envoi = false;
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    _camera.addListener(_rafraichir);
    _camera.initialiser();
    // Compte à rebours du ticket (2 min).
    _minuteur = Timer.periodic(const Duration(seconds: 1), (_) => _rafraichir());
  }

  void _rafraichir() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _camera.removeListener(_rafraichir);
    _camera.dispose();
    super.dispose();
  }

  int get _secondesTicket =>
      widget.ticket.expireA.difference(DateTime.now()).inSeconds.clamp(0, 999).toInt();

  void _surVisages(List<Face> visages) {
    if (_envoi) return;
    if (visages.length != 1) return;
    final v = visages.first;
    // Si un autre visage apparaît (changement de suivi), la vivacité est à refaire.
    if (_idSuivi != null && v.trackingId != null && v.trackingId != _idSuivi) {
      _vivacite.reinitialiser();
    }
    _idSuivi = v.trackingId ?? _idSuivi;
    _vivacite.analyser(
      oeilGauche: v.leftEyeOpenProbability,
      oeilDroit: v.rightEyeOpenProbability,
      sourire: v.smilingProbability,
      lacet: v.headEulerAngleY,
    );
    // Geste trop ancien : la photo doit suivre immédiatement la vivacité.
    if (_vivacite.valide && !_vivacite.valideRecemment()) _vivacite.reinitialiser();
  }

  Future<void> _valider() async {
    setState(() => _envoi = true);
    final t = widget.ticket;
    late final ResultatPointage resultat;
    try {
      final service = await ref.read(faceEmbeddingServiceProvider.future);
      final photo = await _camera.photographier();
      final analyse = await analyserPhoto(
        chemin: photo.path,
        analyseur: ref.read(faceStillAnalyzerProvider),
        service: service,
      );
      if (analyse.embedding == null) {
        // Pas de visage exploitable : on laisse réessayer sans consommer d'essai serveur.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(libellesCodes[analyse.erreur] ?? 'Réessayez.')),
        );
        setState(() => _envoi = false);
        await _camera.demarrerAnalyse();
        return;
      }
      final rep = await ref.read(studentRepositoryProvider).validerPointage(
            ticketId: t.ticketId,
            methode: 'qr_visage',
            embedding: analyse.embedding,
            vivacite: _vivacite.valideRecemment(),
          );
      resultat = ResultatPointage(
        ok: rep.ok,
        code: rep.erreur,
        coursNom: t.coursNom,
        salle: t.salle,
        heure: DateTime.now(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      setState(() => _envoi = false);
      await _camera.demarrerAnalyse();
      return;
    }
    if (!mounted) return;
    context.pushReplacement('/etudiant/resultat', extra: resultat);
  }

  @override
  Widget build(BuildContext context) {
    final unVisage = _camera.visages.length == 1;
    final pret = unVisage && _vivacite.valide && _secondesTicket > 0 && !_envoi;
    final texteVisage = switch (_camera.visages.length) {
      0 => 'Aucun visage détecté',
      1 => 'Visage détecté',
      _ => 'Plusieurs visages détectés',
    };
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Vérification du visage', repli: '/etudiant'),
            Expanded(
              child: _camera.erreur != null
                  ? VueErreur(message: _camera.erreur!)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        children: [
                          FaceOval(
                            camera: _camera,
                            couleurBordure: unVisage ? AppColors.violet : AppColors.puce,
                            largeur: 200,
                            hauteur: 250,
                          ),
                          const SizedBox(height: 20),
                          AppCard(
                            couleur: AppColors.menthe,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _vivacite.valide
                                            ? 'Vivacité confirmée'
                                            : _vivacite.defi.consigne,
                                        style: AppText.sousTitre,
                                      ),
                                    ),
                                    const StatusPill(label: 'Vivacité'),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ProgressPill(valeur: _vivacite.progression),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppCard(
                            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(texteVisage,
                                          style: AppText.sousTitre.copyWith(fontSize: 13)),
                                      Text('Un seul visage, bien éclairé', style: AppText.petit),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: unVisage ? AppColors.menthe : AppColors.puce,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(unVisage ? Icons.check : Icons.more_horiz, size: 16),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _secondesTicket > 0
                                ? 'Ticket valable encore ${Fmt.compteARebours(_secondesTicket)}'
                                : 'Ticket expiré : scannez à nouveau le QR.',
                            style: AppText.petit,
                          ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _secondesTicket > 0
                  ? PillButton(
                      label: 'Valider ma présence',
                      chargement: _envoi,
                      onPressed: pret ? _valider : null,
                    )
                  : PillButton(
                      label: 'Scanner à nouveau',
                      onPressed: () => context.pushReplacement('/etudiant/scan'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
