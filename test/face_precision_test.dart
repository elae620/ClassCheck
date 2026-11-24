import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:classcheck/features/face/data/face_embedding_service.dart';
import 'package:classcheck/features/face/domain/face_alignment.dart';
import 'package:classcheck/features/face/domain/face_math.dart';
import 'package:classcheck/features/face/domain/face_quality.dart';
import 'package:classcheck/features/face/domain/liveness.dart';

List<double> vecteur(double Function(int i) f) =>
    FaceMath.normaliser(List<double>.generate(FaceMath.dimension, (i) => f(i)));

/// Image grise avec deux « yeux » rouges (disques) aux positions données.
img.Image imageAvecYeux(math.Point<double> a, math.Point<double> b, {int w = 400, int h = 400}) {
  final im = img.Image(width: w, height: h)..clear(img.ColorRgb8(120, 120, 120));
  for (final p in [a, b]) {
    img.fillCircle(im, x: p.x.round(), y: p.y.round(), radius: 5, color: img.ColorRgb8(255, 0, 0));
  }
  return im;
}

/// Centre de gravité des pixels rouges dans la moitié gauche / droite du visage aligné.
(math.Point<double>, math.Point<double>) yeuxDansAligne(VisageAligne v) {
  double sx(bool gauche, bool xAxe) {
    var s = 0.0, n = 0;
    for (var y = 0; y < v.taille; y++) {
      for (var x = 0; x < v.taille; x++) {
        if ((x < v.taille / 2) != gauche) continue;
        final i = (y * v.taille + x) * 3;
        // rouge : R élevé, G faible (valeurs normalisées [-1, 1])
        if (v.rgb[i] > 0.5 && v.rgb[i + 1] < -0.3) {
          s += xAxe ? x : y;
          n++;
        }
      }
    }
    return n == 0 ? double.nan : s / n;
  }

  return (
    math.Point(sx(true, true), sx(true, false)),
    math.Point(sx(false, true), sx(false, false)),
  );
}

void main() {
  group('Alignement du visage (FaceAligner)', () {
    void verifierAlignement(math.Point<double> a, math.Point<double> b) {
      final v = FaceAligner.aligner(imageAvecYeux(a, b), a, b);
      final (g, d) = yeuxDansAligne(v);
      // Yeux à l'horizontale, à 46 % de la hauteur, écartés de ~31 % de la largeur.
      expect((g.y - d.y).abs(), lessThan(2.0), reason: 'yeux non horizontaux');
      expect(g.y, closeTo(0.46 * 112, 3));
      expect(d.x - g.x, closeTo(0.3125 * 112, 3));
      expect((g.x + d.x) / 2, closeTo(56, 2));
    }

    test('visage droit', () => verifierAlignement(const math.Point(150, 180), const math.Point(250, 180)));
    test('visage incliné de 25° : redressé', () {
      final c = const math.Point(200.0, 200.0);
      const r = 50.0;
      final t = 25 * math.pi / 180;
      verifierAlignement(
        math.Point(c.x - r * math.cos(t), c.y - r * math.sin(t)),
        math.Point(c.x + r * math.cos(t), c.y + r * math.sin(t)),
      );
    });
    test('visage plus proche (yeux 2× plus écartés) : même cadrage', () =>
        verifierAlignement(const math.Point(100, 150), const math.Point(300, 150)));
    test('ordre des yeux indifférent', () =>
        verifierAlignement(const math.Point(250, 160), const math.Point(150, 175)));

    test('image miroir symétrique', () {
      const a = math.Point(150.0, 180.0), b = math.Point(250.0, 180.0);
      final v = FaceAligner.aligner(imageAvecYeux(a, b), a, b);
      final i = (50 * 112 + 10) * 3;
      final j = (50 * 112 + 101) * 3;
      expect(v.rgbMiroir[j], v.rgb[i]);
    });

    test('préparation dans un isolate depuis une vraie photo JPEG', () async {
      const a = math.Point(500.0, 600.0), b = math.Point(700.0, 610.0);
      final dossier = await Directory.systemTemp.createTemp('classcheck');
      final f = File('${dossier.path}/selfie.jpg')
        ..writeAsBytesSync(img.encodeJpg(imageAvecYeux(a, b, w: 1200, h: 1600)));
      final chrono = Stopwatch()..start();
      final v = await compute(
        preparerVisage,
        RequeteVisage(chemin: f.path, taille: 112, yeux: [a.x, a.y, b.x, b.y], cadre: const [0, 0, 1, 1]),
      );
      chrono.stop();
      final (g, d) = yeuxDansAligne(v);
      expect((g.y - d.y).abs(), lessThan(2.5));
      expect(v.rgb.length, 112 * 112 * 3);
      // ignore: avoid_print
      print('Préparation photo 1200×1600 : ${chrono.elapsedMilliseconds} ms');
      await dossier.delete(recursive: true);
    });

    test('yeux confondus refusés', () {
      const a = math.Point(150.0, 180.0);
      expect(() => FaceAligner.aligner(imageAvecYeux(a, a), a, a), throwsStateError);
    });
  });

  group('Contrôles de qualité (FaceQuality)', () {
    test('pose de face acceptée', () {
      expect(
        FaceQuality.verifierPose(largeurVisage: 200, lacet: 4, tangage: -3, oeilGauche: 0.9, oeilDroit: 0.9),
        isNull,
      );
    });
    test('visage de profil refusé pour la vérification, toléré à l\'enregistrement', () {
      expect(FaceQuality.verifierPose(largeurVisage: 200, lacet: 28), 'visage_de_profil');
      expect(FaceQuality.verifierPose(largeurVisage: 200, lacet: 28, frontal: false), isNull);
    });
    test('visage trop petit (trop loin) refusé', () {
      expect(FaceQuality.verifierPose(largeurVisage: 60), 'visage_trop_petit');
    });
    test('yeux fermés refusés', () {
      expect(FaceQuality.verifierPose(largeurVisage: 200, oeilGauche: 0.1, oeilDroit: 0.2), 'yeux_fermes');
    });

    test('netteté : image uniforme (floue) < image texturée', () {
      final uni = List<double>.filled(112 * 112, 128);
      final damier = [for (var i = 0; i < 112 * 112; i++) ((i ~/ 112 + i % 112) % 2) * 200.0 + 20];
      expect(FaceQuality.nettete(uni, 112, 112), 0);
      expect(FaceQuality.nettete(damier, 112, 112), greaterThan(FaceQuality.netteteMin));
      expect(FaceQuality.verifierImage(uni, 112, 112), 'visage_flou');
      expect(FaceQuality.verifierImage(damier, 112, 112), isNull);
    });
    test('éclairage : trop sombre / trop clair refusé', () {
      expect(FaceQuality.verifierImage(List.filled(112 * 112, 10), 112, 112), 'mauvais_eclairage');
      expect(FaceQuality.verifierImage(List.filled(112 * 112, 250), 112, 112), 'mauvais_eclairage');
    });
    test('angle des yeux', () {
      expect(FaceQuality.angleYeux(const math.Point(0, 0), const math.Point(10, 10)), closeTo(45, 1e-9));
      expect(FaceQuality.angleYeux(const math.Point(10, 10), const math.Point(0, 0)), closeTo(45, 1e-9));
    });
  });

  group('Décision par vote sur les 5 captures', () {
    final a = vecteur((i) => (i % 7) + 1.0);
    final autre = vecteur((i) => i.isEven ? -1 : 1);
    final proche = vecteur((i) => (i % 7) + 1.0 + (i % 5 == 0 ? 0.3 : 0));

    test('même personne : 5 votes, accepté', () {
      final refs = FaceMath.aplatir(List.filled(5, a));
      expect(FaceMath.votes(proche, refs), 5);
      expect(FaceMath.accepte(proche, refs), isTrue);
    });
    test('une seule capture ressemblante (capture ratée) : refusé avec 2 votes requis', () {
      final refs = FaceMath.aplatir([a, autre, autre, autre, autre]);
      expect(FaceMath.distanceMin(proche, refs), lessThan(1.0));
      expect(FaceMath.votes(proche, refs), 1);
      expect(FaceMath.accepte(proche, refs), isFalse);
      expect(FaceMath.accepte(proche, refs, votesRequis: 1), isTrue);
    });
    test('autre personne : refusé', () {
      expect(FaceMath.accepte(autre, FaceMath.aplatir(List.filled(5, a))), isFalse);
    });
    test('dispersion : captures cohérentes / incohérentes', () {
      expect(FaceMath.dispersion([a, proche, a, a, a]), lessThan(1.3));
      expect(FaceMath.dispersion([a, a, a, a, autre]), greaterThan(1.3));
    });
  });

  group('Vivacité renforcée', () {
    test('rotation : face → tournée → face', () {
      final l = LivenessDetector(defi: DefiVivacite.rotation);
      expect(l.analyser(lacet: 2), isFalse);
      expect(l.analyser(lacet: 26), isFalse);
      expect(l.analyser(lacet: -3), isTrue);
      expect(l.mode, 'rotation');
    });
    test('rotation : tête immobile (photo) refusée', () {
      final l = LivenessDetector(defi: DefiVivacite.rotation);
      for (var i = 0; i < 40; i++) {
        l.analyser(lacet: 1, oeilGauche: 0.9, oeilDroit: 0.9);
      }
      expect(l.valide, isFalse);
    });
    test('rotation : clignement ne suffit pas', () {
      final l = LivenessDetector(defi: DefiVivacite.rotation);
      l.analyser(oeilGauche: 0.9, oeilDroit: 0.9, lacet: 0);
      l.analyser(oeilGauche: 0.1, oeilDroit: 0.1, lacet: 0);
      l.analyser(oeilGauche: 0.9, oeilDroit: 0.9, lacet: 0);
      expect(l.valide, isFalse);
    });
    test('la validation expire (photo prise trop tard)', () {
      final t0 = DateTime(2026, 1, 1, 10);
      final l = LivenessDetector()..analyser(sourire: 0.95, maintenant: t0);
      expect(l.valideRecemment(t0.add(const Duration(seconds: 3))), isTrue);
      expect(l.valideRecemment(t0.add(const Duration(seconds: 9))), isFalse);
    });
    test('défi tiré au hasard', () {
      final vus = {for (var s = 0; s < 20; s++) DefiVivacite.auHasard(math.Random(s))};
      expect(vus, containsAll(DefiVivacite.values));
    });
  });
}
