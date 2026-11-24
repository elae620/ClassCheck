import 'package:flutter_test/flutter_test.dart';

import 'package:classcheck/features/face/domain/liveness.dart';

void main() {
  test('clignement : ouverts → fermés → ouverts', () {
    final l = LivenessDetector();
    expect(l.analyser(oeilGauche: 0.9, oeilDroit: 0.9), isFalse);
    expect(l.analyser(oeilGauche: 0.1, oeilDroit: 0.1), isFalse);
    expect(l.analyser(oeilGauche: 0.95, oeilDroit: 0.9), isTrue);
    expect(l.mode, 'clignement');
  });

  test('photo fixe (yeux toujours ouverts) : refusée', () {
    final l = LivenessDetector();
    for (var i = 0; i < 50; i++) {
      l.analyser(oeilGauche: 0.9, oeilDroit: 0.88, sourire: 0.1);
    }
    expect(l.valide, isFalse);
  });

  test('yeux fermés sans ouverture préalable : pas de validation', () {
    final l = LivenessDetector();
    l.analyser(oeilGauche: 0.1, oeilDroit: 0.1);
    l.analyser(oeilGauche: 0.9, oeilDroit: 0.9);
    expect(l.valide, isFalse);
  });

  test('sourire franc accepté', () {
    final l = LivenessDetector();
    expect(l.analyser(sourire: 0.92), isTrue);
    expect(l.mode, 'sourire');
  });

  test('réinitialisation', () {
    final l = LivenessDetector()..analyser(sourire: 0.95);
    l.reinitialiser();
    expect(l.valide, isFalse);
    expect(l.progression, 0);
  });
}
