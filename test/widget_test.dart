import 'package:flutter_test/flutter_test.dart';

import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/utils/validateurs.dart';
import 'package:classcheck/features/student/domain/pointage.dart';

/// Tests des utilitaires et de l'affichage des résultats de pointage.
void main() {
  group('Fmt', () {
    test('classe normalisée', () {
      expect(Fmt.normaliserClasse('dsi2'), 'DSI 2');
      expect(Fmt.normaliserClasse('  Dsi   2 '), 'DSI 2');
    });

    test('noms et dates', () {
      expect(Fmt.nomCourt('Ali Ben Salah'), 'Ali B.');
      expect(Fmt.nomCourt('Sara M.'), 'Sara M.');
      expect(Fmt.jourCourt(DateTime(2026, 11, 12)), '12 nov');
      expect(Fmt.plage('10:00:00', '12:00:00'), '10:00 – 12:00');
      expect(Fmt.compteARebours(18), '0:18');
      expect(Fmt.lundi(DateTime(2026, 11, 20)), DateTime(2026, 11, 16));
    });
  });

  group('Validateurs', () {
    test('e-mail', () {
      expect(validerEmail('ali@ecole.tn'), isNull);
      expect(validerEmail('ali'), isNotNull);
    });
    test('mot de passe 8 caractères', () {
      expect(validerMotDePasse('1234567'), isNotNull);
      expect(validerMotDePasse('12345678'), isNull);
    });
  });

  group('ResultatPointage', () {
    test('QR expiré au scan', () {
      const r = ResultatPointage(ok: false, code: 'qr_expire', etape: EtapePointage.scan);
      expect(r.lignes, contains(('QR code', 'Expiré')));
      expect(r.lignes, contains(('Visage', 'Non vérifié')));
      expect(r.doitRescanner, isTrue);
    });

    test('mauvais visage', () {
      const r = ResultatPointage(ok: false, code: 'visage_non_reconnu');
      expect(r.lignes, contains(('Visage', 'Non reconnu')));
    });

    test('succès', () {
      const r = ResultatPointage(ok: true);
      expect(r.lignes.length, 3);
    });
  });
}
