import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:classcheck/core/data/seance_repository.dart';
import 'package:classcheck/core/models/qr_seance.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/messages_erreur.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/student/data/student_repository.dart';
import 'package:classcheck/features/student/domain/pointage.dart';
import 'package:classcheck/features/student/presentation/widgets/etapes_pointage.dart';

/// Maquette « Etudiant-Scan » — étape 1 : scan du QR dynamique.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _traitement = false;
  DateTime _dernierAvertissement = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _surDetection(BarcodeCapture capture) async {
    if (_traitement || capture.barcodes.isEmpty) return;
    final payload = QrPayload.decoder(capture.barcodes.first.rawValue);
    if (payload == null) {
      final n = DateTime.now();
      if (n.difference(_dernierAvertissement).inSeconds > 3) {
        _dernierAvertissement = n;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce QR code n\'est pas un code de séance ClassCheck.')),
        );
      }
      return;
    }

    setState(() => _traitement = true);
    final repo = ref.read(studentRepositoryProvider);
    try {
      await _scanner.stop();
      final rep = await repo.scannerQr(payload.seanceId, payload.token);
      if (!mounted) return;
      if (!rep.ok) {
        context.pushReplacement(
          '/etudiant/resultat',
          extra: ResultatPointage(ok: false, code: rep.erreur, etape: EtapePointage.scan),
        );
        return;
      }
      final ticket = TicketPointage.fromMap(rep.donnees);
      if (ticket.visageObligatoire) {
        context.pushReplacement('/etudiant/selfie', extra: ticket);
        return;
      }
      // Séance sans vérification faciale : validation directe par QR.
      final val = await repo.validerPointage(ticketId: ticket.ticketId, methode: 'qr');
      if (!mounted) return;
      context.pushReplacement(
        '/etudiant/resultat',
        extra: ResultatPointage(
          ok: val.ok,
          code: val.erreur,
          coursNom: ticket.coursNom,
          salle: ticket.salle,
          heure: DateTime.now(),
          visageVerifie: false,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      setState(() => _traitement = false);
      await _scanner.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final duree = ref.watch(reglesProvider).valueOrNull?.renouvellementQr ?? 30;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Scanner le QR', repli: '/etudiant'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  children: [
                    Text(
                      'Placez le code projeté par l\'enseignant dans le cadre',
                      textAlign: TextAlign.center,
                      style: AppText.secondaire,
                    ),
                    const SizedBox(height: 18),
                    _CadreScan(
                      traitement: _traitement,
                      child: MobileScanner(
                        controller: _scanner,
                        onDetect: _surDetection,
                        errorBuilder: (context, erreur, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              erreur.errorCode == MobileScannerErrorCode.permissionDenied
                                  ? 'Accès à la caméra refusé.'
                                  : 'Caméra indisponible.',
                              textAlign: TextAlign.center,
                              style: AppText.secondaire,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const EtapesPointage(etape: 0),
                    const SizedBox(height: 18),
                    AppCard(
                      couleur: AppColors.jaune,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('Code valable $duree s', style: AppText.sousTitre),
                              ),
                              StatusPill(label: '$duree s'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Le code change automatiquement : une capture d\'écran ne fonctionne pas.',
                            style: AppText.petit,
                          ),
                        ],
                      ),
                    ),
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

/// Cadre lavande arrondi avec bordure en pointillés.
class _CadreScan extends StatelessWidget {
  const _CadreScan({required this.traitement, required this.child});
  final Widget child;
  final bool traitement;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lavande,
        borderRadius: BorderRadius.circular(28),
      ),
      child: CustomPaint(
        foregroundPainter: _PointillesPainter(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (traitement)
                const ColoredBox(
                  color: Color(0x88D9CCF0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointillesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final peinture = Paint()
      ..color = const Color(0xFF7D63C9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final chemin = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)));
    for (final metrique in chemin.computeMetrics()) {
      var d = 0.0;
      while (d < metrique.length) {
        canvas.drawPath(metrique.extractPath(d, d + 6), peinture);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
