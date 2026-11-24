import 'package:flutter_test/flutter_test.dart';

import 'package:classcheck/core/models/qr_seance.dart';

void main() {
  const seance = '00000000-0000-4000-b000-000000000001';
  const token = '0123456789abcdef0123456789abcdef';

  group('Validité du token QR (30 s)', () {
    final t0 = DateTime(2026, 11, 20, 10, 0, 0);
    final qr = QrToken(seanceId: seance, token: token, dureeSecondes: 30, recuA: t0);

    test('valide juste après génération', () {
      expect(qr.estValide(t0), isTrue);
      expect(qr.secondesRestantes(t0), 30);
      expect(qr.progression(t0), 1);
    });

    test('valide à 29 s, expiré à 30 s', () {
      expect(qr.estValide(t0.add(const Duration(seconds: 29))), isTrue);
      expect(qr.estValide(t0.add(const Duration(seconds: 30))), isFalse);
    });

    test('compte à rebours arrondi à la seconde supérieure', () {
      expect(qr.secondesRestantes(t0.add(const Duration(milliseconds: 12500))), 18);
    });

    test('jamais négatif après expiration', () {
      expect(qr.secondesRestantes(t0.add(const Duration(minutes: 5))), 0);
      expect(qr.progression(t0.add(const Duration(minutes: 5))), 0);
    });

    test('durée configurable (règle renouvellement_qr)', () {
      final q = QrToken(seanceId: seance, token: token, dureeSecondes: 60, recuA: t0);
      expect(q.estValide(t0.add(const Duration(seconds: 45))), isTrue);
    });
  });

  group('Contenu du QR', () {
    test('aller-retour encoder / décoder', () {
      final p = QrPayload.decoder(const QrPayload(seanceId: seance, token: token).encoder());
      expect(p, isNotNull);
      expect(p!.seanceId, seance);
      expect(p.token, token);
    });

    test('QR étranger refusé', () {
      expect(QrPayload.decoder('https://exemple.com'), isNull);
      expect(QrPayload.decoder(null), isNull);
      expect(QrPayload.decoder('classcheck:v1:pas-un-uuid:$token'), isNull);
      expect(QrPayload.decoder('classcheck:v1:$seance:court'), isNull);
      expect(QrPayload.decoder('classcheck:v1:$seance:$token:extra'), isNull);
    });
  });
}
