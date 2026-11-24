import 'dart:math' as math;

/// Calculs sur les embeddings de visage (192 valeurs).
/// La même règle est appliquée côté serveur dans `distance_min_visage`.
class FaceMath {
  FaceMath._();

  static const dimension = 192;
  static const nbCaptures = 5;
  static const seuilParDefaut = 1.0;

  /// Distance euclidienne entre deux vecteurs de même taille.
  static double distance(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Tailles différentes : ${a.length} et ${b.length}');
    }
    var somme = 0.0;
    for (var i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      somme += d * d;
    }
    return math.sqrt(somme);
  }

  /// Normalisation L2 (norme 1) : les distances sont alors comprises entre 0 et 2.
  static List<double> normaliser(List<double> v) {
    var norme = 0.0;
    for (final x in v) {
      norme += x * x;
    }
    norme = math.sqrt(norme);
    if (norme == 0) return List<double>.from(v);
    return [for (final x in v) x / norme];
  }

  /// Plus petite distance entre [sonde] et chacun des embeddings concaténés
  /// dans [references] (N × [dim] valeurs).
  static double distanceMin(List<double> sonde, List<double> references,
      {int dim = dimension}) {
    if (sonde.length != dim) throw ArgumentError('La sonde doit contenir $dim valeurs');
    if (references.isEmpty || references.length % dim != 0) {
      throw ArgumentError('Références invalides (${references.length} valeurs)');
    }
    var min = double.infinity;
    for (var k = 0; k < references.length ~/ dim; k++) {
      final d = distance(sonde, references.sublist(k * dim, (k + 1) * dim));
      if (d < min) min = d;
    }
    return min;
  }

  /// Vrai si le visage correspond (distance ≤ seuil).
  static bool correspond(List<double> sonde, List<double> references,
          {double seuil = seuilParDefaut}) =>
      distanceMin(sonde, references) <= seuil;

  /// Plus grande distance entre deux captures d'un même enregistrement.
  /// Une valeur élevée signale des captures de personnes différentes ou ratées
  /// (même règle que `dispersion_visage` côté serveur).
  static double dispersion(List<List<double>> embeddings) {
    var max = 0.0;
    for (var a = 0; a < embeddings.length; a++) {
      for (var b = a + 1; b < embeddings.length; b++) {
        final d = distance(embeddings[a], embeddings[b]);
        if (d > max) max = d;
      }
    }
    return max;
  }

  /// Nombre de références (sur N) à une distance <= [seuil] de la sonde
  /// (même règle que `votes_visage` côté serveur).
  static int votes(List<double> sonde, List<double> references,
      {double seuil = seuilParDefaut, int dim = dimension}) {
    var n = 0;
    for (var k = 0; k < references.length ~/ dim; k++) {
      if (distance(sonde, references.sublist(k * dim, (k + 1) * dim)) <= seuil) n++;
    }
    return n;
  }

  /// Règle d'acceptation complète : distance minimale sous le seuil ET au
  /// moins [votesRequis] captures d'accord (rejette les ressemblances fortuites
  /// avec une seule capture ratée).
  static bool accepte(List<double> sonde, List<double> references,
      {double seuil = seuilParDefaut, int votesRequis = 2}) {
    final n = references.length ~/ dimension;
    return distanceMin(sonde, references) <= seuil &&
        votes(sonde, references, seuil: seuil) >= math.min(votesRequis, n);
  }

  /// Concatène les captures avant l'envoi à `enregistrer_visage`.
  static List<double> aplatir(List<List<double>> embeddings) {
    for (final e in embeddings) {
      if (e.length != dimension) throw ArgumentError('Embedding de taille ${e.length}');
    }
    return [for (final e in embeddings) ...e];
  }
}
