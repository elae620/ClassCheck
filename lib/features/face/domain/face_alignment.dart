import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:classcheck/features/face/domain/face_quality.dart';

/// Visage aligné prêt pour le modèle : pixels RGB normalisés dans [-1, 1]
/// (normal et miroir) + niveaux de gris pour les contrôles de qualité.
class VisageAligne {
  VisageAligne(this.taille, this.rgb, this.rgbMiroir, this.gris);
  final int taille;

  /// taille × taille × 3 valeurs, ligne par ligne.
  final Float32List rgb;
  final Float32List rgbMiroir;

  /// taille × taille valeurs 0–255.
  final List<double> gris;
}

/// Alignement géométrique du visage, comme lors de l'entraînement de
/// MobileFaceNet : yeux à l'horizontale, écart des yeux fixe, yeux à 46 %
/// de la hauteur. Un visage incliné ou plus ou moins proche donne alors le
/// même cadrage, ce qui rend les embeddings bien plus stables.
///
/// Implémenté par transformation affine inverse + interpolation bilinéaire
/// (une seule passe sur les 112×112 pixels de sortie).
class FaceAligner {
  FaceAligner._();

  /// [oeilA]/[oeilB] : centres des yeux dans [image] (ordre indifférent).
  static VisageAligne aligner(
    img.Image image,
    math.Point<double> oeilA,
    math.Point<double> oeilB, {
    int taille = 112,
  }) {
    final (g, d) = oeilA.x <= oeilB.x ? (oeilA, oeilB) : (oeilB, oeilA);
    final dx = d.x - g.x;
    final dy = d.y - g.y;
    final ecart = math.sqrt(dx * dx + dy * dy);
    if (ecart < 4) throw StateError('Yeux trop proches pour aligner le visage');
    final cos = dx / ecart;
    final sin = dy / ecart;
    final milieu = math.Point((g.x + d.x) / 2, (g.y + d.y) / 2);
    // Pixels source par pixel de sortie.
    final k = FaceQuality.coteRecadrage(ecart) / taille;
    final cibleX = taille / 2;
    final cibleY = FaceQuality.hauteurYeux * taille;
    return _echantillonner(image, taille, (u, v) {
      final ox = (u - cibleX) * k;
      final oy = (v - cibleY) * k;
      return (milieu.x + cos * ox - sin * oy, milieu.y + sin * ox + cos * oy);
    });
  }

  /// Repli sans repères des yeux : carré centré sur le cadre du visage (+10 %).
  static VisageAligne recadrer(
    img.Image image, {
    required double gauche,
    required double haut,
    required double largeur,
    required double hauteur,
    int taille = 112,
  }) {
    final cote = math.max(largeur, hauteur) * 1.1;
    final cx = gauche + largeur / 2;
    final cy = haut + hauteur / 2;
    final k = cote / taille;
    return _echantillonner(image, taille,
        (u, v) => (cx + (u - taille / 2) * k, cy + (v - taille / 2) * k));
  }

  static VisageAligne _echantillonner(
    img.Image image,
    int taille,
    (double, double) Function(double u, double v) source,
  ) {
    final rgb = Float32List(taille * taille * 3);
    final miroir = Float32List(taille * taille * 3);
    final gris = List<double>.filled(taille * taille, 0);
    for (var v = 0; v < taille; v++) {
      for (var u = 0; u < taille; u++) {
        final (sx, sy) = source(u + 0.5, v + 0.5);
        final (r, gv, b) = _bilineaire(image, sx - 0.5, sy - 0.5);
        final i = (v * taille + u) * 3;
        final j = (v * taille + (taille - 1 - u)) * 3;
        rgb[i] = miroir[j] = (r - 127.5) / 128;
        rgb[i + 1] = miroir[j + 1] = (gv - 127.5) / 128;
        rgb[i + 2] = miroir[j + 2] = (b - 127.5) / 128;
        gris[v * taille + u] = 0.299 * r + 0.587 * gv + 0.114 * b;
      }
    }
    return VisageAligne(taille, rgb, miroir, gris);
  }

  static (double, double, double) _bilineaire(img.Image im, double x, double y) {
    final w = im.width, h = im.height;
    final xc = x.clamp(0.0, w - 1.0);
    final yc = y.clamp(0.0, h - 1.0);
    final x0 = xc.floor(), y0 = yc.floor();
    final x1 = math.min(x0 + 1, w - 1), y1 = math.min(y0 + 1, h - 1);
    final fx = xc - x0, fy = yc - y0;
    final p00 = im.getPixel(x0, y0), p10 = im.getPixel(x1, y0);
    final p01 = im.getPixel(x0, y1), p11 = im.getPixel(x1, y1);
    double mix(num a, num b, num c, num d) =>
        (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy;
    return (
      mix(p00.r, p10.r, p01.r, p11.r),
      mix(p00.g, p10.g, p01.g, p11.g),
      mix(p00.b, p10.b, p01.b, p11.b),
    );
  }
}
