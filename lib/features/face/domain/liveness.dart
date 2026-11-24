import 'dart:math' as math;

/// Défi de vivacité demandé à l'étudiant. Il est tiré au hasard à chaque
/// pointage : une vidéo préenregistrée ne sait pas à l'avance quoi faire.
enum DefiVivacite {
  /// Cligner des yeux (un sourire franc est aussi accepté).
  clignement('Clignez des yeux'),

  /// Tourner la tête d'un côté puis revenir de face.
  rotation('Tournez la tête puis revenez de face');

  const DefiVivacite(this.consigne);
  final String consigne;

  static DefiVivacite auHasard([math.Random? aleatoire]) =>
      values[(aleatoire ?? math.Random.secure()).nextInt(values.length)];
}

/// Test de vivacité à partir des probabilités et angles fournis par ML Kit :
/// - clignement : yeux ouverts → fermés → ouverts (ou sourire franc) ;
/// - rotation : de face → tête tournée (≥ 20°) → de face.
/// Une photo imprimée ou un écran ne cligne pas et ne tourne pas la tête.
/// La validation expire après [dureeValidite] : la photo doit être prise
/// juste après le geste.
class LivenessDetector {
  LivenessDetector({
    this.defi = DefiVivacite.clignement,
    this.seuilOuvert = 0.7,
    this.seuilFerme = 0.25,
    this.seuilSourire = 0.85,
    this.angleRotation = 20,
    this.angleFace = 8,
    this.dureeValidite = const Duration(seconds: 8),
  });

  final DefiVivacite defi;
  final double seuilOuvert;
  final double seuilFerme;
  final double seuilSourire;
  final double angleRotation;
  final double angleFace;
  final Duration dureeValidite;

  bool _ouvertsVus = false;
  bool _fermesVus = false;
  bool _faceVue = false;
  bool _tourneVu = false;
  bool _valide = false;
  DateTime? _valideA;
  String? _mode;

  bool get valide => _valide;

  /// « clignement », « sourire » ou « rotation » une fois validé.
  String? get mode => _mode;

  /// Vrai si la vivacité a été confirmée il y a moins de [dureeValidite].
  bool valideRecemment([DateTime? maintenant]) =>
      _valide &&
      _valideA != null &&
      (maintenant ?? DateTime.now()).difference(_valideA!) <= dureeValidite;

  double get progression {
    if (_valide) return 1.0;
    return switch (defi) {
      DefiVivacite.clignement => _fermesVus ? 0.66 : (_ouvertsVus ? 0.33 : 0.0),
      DefiVivacite.rotation => _tourneVu ? 0.66 : (_faceVue ? 0.33 : 0.0),
    };
  }

  void reinitialiser() {
    _ouvertsVus = false;
    _fermesVus = false;
    _faceVue = false;
    _tourneVu = false;
    _valide = false;
    _valideA = null;
    _mode = null;
  }

  void _valider(String mode, DateTime? maintenant) {
    _valide = true;
    _mode = mode;
    _valideA = maintenant ?? DateTime.now();
  }

  /// Analyse une image ; renvoie vrai dès que la vivacité est confirmée.
  /// [lacet] : angle gauche/droite de la tête (Euler Y de ML Kit).
  bool analyser({
    double? oeilGauche,
    double? oeilDroit,
    double? sourire,
    double? lacet,
    DateTime? maintenant,
  }) {
    if (_valide) return true;
    switch (defi) {
      case DefiVivacite.clignement:
        if (sourire != null && sourire >= seuilSourire) {
          _valider('sourire', maintenant);
          return true;
        }
        if (oeilGauche == null || oeilDroit == null) return false;
        final moyenne = (oeilGauche + oeilDroit) / 2;
        if (moyenne >= seuilOuvert) {
          if (_fermesVus) {
            _valider('clignement', maintenant);
          } else {
            _ouvertsVus = true;
          }
        } else if (moyenne <= seuilFerme && _ouvertsVus) {
          _fermesVus = true;
        }
      case DefiVivacite.rotation:
        if (lacet == null) return false;
        final a = lacet.abs();
        if (a <= angleFace) {
          if (_tourneVu) {
            _valider('rotation', maintenant);
          } else {
            _faceVue = true;
          }
        } else if (a >= angleRotation && _faceVue) {
          _tourneVu = true;
        }
    }
    return _valide;
  }
}
