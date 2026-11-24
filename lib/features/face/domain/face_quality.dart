import 'dart:math' as math;

/// Contrôles de qualité appliqués AVANT de calculer un embedding.
/// Un embedding calculé sur une photo floue, sombre, de profil ou trop
/// petite est peu fiable : il augmente à la fois les faux refus et les
/// fausses acceptations. Ces règles sont pures (testables sans caméra).
class FaceQuality {
  FaceQuality._();

  /// Angles maximaux (degrés) pour une photo de vérification.
  static const lacetMaxFrontal = 15.0; // gauche/droite (Euler Y)
  static const tangageMaxFrontal = 15.0; // haut/bas (Euler X)
  static const roulisMax = 25.0; // inclinaison (Euler Z), corrigée par l'alignement

  /// Largeur minimale du visage en pixels dans la photo.
  static const largeurMin = 110.0;

  /// Netteté minimale (variance du laplacien sur le visage 112×112 en niveaux de gris).
  static const netteteMin = 18.0;

  /// Luminosité moyenne acceptable (0–255).
  static const luminositeMin = 45.0;
  static const luminositeMax = 225.0;

  /// Vérifie la pose et la taille. [frontal] : photo de vérification
  /// (les captures d'enregistrement de côté tolèrent un lacet de 40°).
  /// Renvoie un code d'erreur ou null si tout va bien.
  static String? verifierPose({
    required double largeurVisage,
    double? lacet,
    double? tangage,
    double? roulis,
    double? oeilGauche,
    double? oeilDroit,
    bool frontal = true,
  }) {
    if (largeurVisage < largeurMin) return 'visage_trop_petit';
    final y = (lacet ?? 0).abs();
    final x = (tangage ?? 0).abs();
    if (frontal && (y > lacetMaxFrontal || x > tangageMaxFrontal)) return 'visage_de_profil';
    if (!frontal && (y > 40 || x > 35)) return 'visage_de_profil';
    if ((roulis ?? 0).abs() > roulisMax) return 'visage_de_profil';
    if (oeilGauche != null && oeilDroit != null && (oeilGauche + oeilDroit) / 2 < 0.35) {
      return 'yeux_fermes';
    }
    return null;
  }

  /// Variance du laplacien (mesure classique de netteté) sur une image en
  /// niveaux de gris de [largeur] × [hauteur] pixels (valeurs 0–255).
  static double nettete(List<double> gris, int largeur, int hauteur) {
    if (largeur < 3 || hauteur < 3 || gris.length != largeur * hauteur) return 0;
    var somme = 0.0;
    var sommeCarres = 0.0;
    var n = 0;
    for (var y = 1; y < hauteur - 1; y++) {
      for (var x = 1; x < largeur - 1; x++) {
        final i = y * largeur + x;
        final lap = gris[i - largeur] + gris[i + largeur] + gris[i - 1] + gris[i + 1] - 4 * gris[i];
        somme += lap;
        sommeCarres += lap * lap;
        n++;
      }
    }
    final moyenne = somme / n;
    return sommeCarres / n - moyenne * moyenne;
  }

  static double luminosite(List<double> gris) =>
      gris.isEmpty ? 0 : gris.reduce((a, b) => a + b) / gris.length;

  /// Vérifie netteté et exposition du visage recadré. Code d'erreur ou null.
  static String? verifierImage(List<double> gris, int largeur, int hauteur) {
    final l = luminosite(gris);
    if (l < luminositeMin || l > luminositeMax) return 'mauvais_eclairage';
    if (nettete(gris, largeur, hauteur) < netteteMin) return 'visage_flou';
    return null;
  }

  /// Angle (degrés) de la droite qui passe par les deux yeux : c'est la
  /// rotation à annuler pour aligner le visage (yeux à l'horizontale).
  static double angleYeux(math.Point<double> oeilA, math.Point<double> oeilB) {
    final (g, d) = oeilA.x <= oeilB.x ? (oeilA, oeilB) : (oeilB, oeilA);
    return math.atan2(d.y - g.y, d.x - g.x) * 180 / math.pi;
  }

  /// Côté du carré à recadrer pour MobileFaceNet : sur les visages alignés
  /// d'entraînement (112×112), les yeux sont écartés d'environ 35 px,
  /// soit 31 % de la largeur.
  static double coteRecadrage(double distanceYeux) => distanceYeux / 0.3125;

  /// Position verticale relative des yeux dans le carré aligné (≈ 51/112).
  static const hauteurYeux = 0.46;
}
