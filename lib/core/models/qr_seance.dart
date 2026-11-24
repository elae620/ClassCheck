/// Contenu du QR dynamique projeté par l'enseignant.
/// Format : `classcheck:v1:<seance_id>:<token>`
class QrPayload {
  const QrPayload({required this.seanceId, required this.token});

  static const prefixe = 'classcheck:v1:';

  final String seanceId;
  final String token;

  String encoder() => '$prefixe$seanceId:$token';

  /// Renvoie null si le texte scanné n'est pas un QR ClassCheck valide.
  static QrPayload? decoder(String? brut) {
    if (brut == null || !brut.startsWith(prefixe)) return null;
    final parties = brut.substring(prefixe.length).split(':');
    if (parties.length != 2) return null;
    final uuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    final token = RegExp(r'^[0-9a-f]{32}$');
    if (!uuid.hasMatch(parties[0]) || !token.hasMatch(parties[1])) return null;
    return QrPayload(seanceId: parties[0], token: parties[1]);
  }
}

/// Jeton QR généré par `generer_qr`. La validité réelle est contrôlée par le
/// serveur ; côté application on gère seulement le compte à rebours.
class QrToken {
  QrToken({
    required this.seanceId,
    required this.token,
    required this.dureeSecondes,
    DateTime? recuA,
  }) : recuA = recuA ?? DateTime.now();

  final String seanceId;
  final String token;
  final int dureeSecondes;

  /// Heure locale de réception : on ne dépend pas de l'horloge du serveur.
  final DateTime recuA;

  factory QrToken.fromMap(Map<String, dynamic> m) => QrToken(
        seanceId: m['seance_id'] as String,
        token: m['token'] as String,
        dureeSecondes: (m['duree'] ?? 30) as int,
      );

  DateTime get expireA => recuA.add(Duration(seconds: dureeSecondes));

  int secondesRestantes([DateTime? maintenant]) {
    final ms = expireA.difference(maintenant ?? DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  bool estValide([DateTime? maintenant]) =>
      (maintenant ?? DateTime.now()).isBefore(expireA);

  /// Fraction de temps restante (barre de progression).
  double progression([DateTime? maintenant]) =>
      dureeSecondes == 0 ? 0.0 : secondesRestantes(maintenant) / dureeSecondes;

  String get contenu => QrPayload(seanceId: seanceId, token: token).encoder();
}
