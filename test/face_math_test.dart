import 'package:flutter_test/flutter_test.dart';

import 'package:classcheck/features/face/domain/face_math.dart';

List<double> vecteur(double Function(int i) f) =>
    FaceMath.normaliser(List<double>.generate(FaceMath.dimension, (i) => f(i)));

void main() {
  group('FaceMath.distance', () {
    test('distance nulle pour deux vecteurs identiques', () {
      final a = vecteur((i) => i.toDouble());
      expect(FaceMath.distance(a, List.of(a)), 0);
    });

    test('distance euclidienne correcte', () {
      expect(FaceMath.distance([0, 0], [3, 4]), 5);
    });

    test('tailles différentes refusées', () {
      expect(() => FaceMath.distance([1, 2], [1]), throwsArgumentError);
    });
  });

  group('FaceMath.normaliser', () {
    test('norme 1 après normalisation', () {
      final v = FaceMath.normaliser([3, 4]);
      expect(v[0], closeTo(0.6, 1e-9));
      expect(v[1], closeTo(0.8, 1e-9));
    });

    test('vecteur nul inchangé', () {
      expect(FaceMath.normaliser([0, 0]), [0, 0]);
    });

    test('distance entre vecteurs normalisés comprise entre 0 et 2', () {
      final a = vecteur((i) => 1);
      final b = vecteur((i) => -1);
      expect(FaceMath.distance(a, b), closeTo(2, 1e-9));
    });
  });

  group('FaceMath.distanceMin / correspond (seuil 1.0)', () {
    final reference = vecteur((i) => (i % 7).toDouble() + 1);
    final references = FaceMath.aplatir(List.generate(5, (_) => reference));

    test('même visage (léger bruit) : accepté', () {
      final sonde = vecteur((i) => (i % 7).toDouble() + 1 + (i.isEven ? 0.05 : -0.05));
      expect(FaceMath.distanceMin(sonde, references), lessThan(1.0));
      expect(FaceMath.correspond(sonde, references), isTrue);
    });

    test('visage différent : refusé', () {
      final sonde = vecteur((i) => i.isEven ? -1 : 1);
      expect(FaceMath.correspond(sonde, references), isFalse);
    });

    test('la plus petite distance parmi les 5 captures est retenue', () {
      final autre = vecteur((i) => i.isEven ? -1 : 1);
      final mix = FaceMath.aplatir([autre, autre, reference, autre, autre]);
      expect(FaceMath.distanceMin(reference, mix), closeTo(0, 1e-9));
    });

    test('seuil configurable', () {
      final sonde = vecteur((i) => (i % 5).toDouble());
      final d = FaceMath.distanceMin(sonde, references);
      expect(FaceMath.correspond(sonde, references, seuil: d + 0.01), isTrue);
      expect(FaceMath.correspond(sonde, references, seuil: d - 0.01), isFalse);
    });

    test('références de taille invalide refusées', () {
      expect(() => FaceMath.distanceMin(reference, [1, 2, 3]), throwsArgumentError);
    });

    test('aplatir exige 192 valeurs par embedding', () {
      expect(() => FaceMath.aplatir([[1, 2]]), throwsArgumentError);
      expect(references.length, 960);
    });
  });
}
