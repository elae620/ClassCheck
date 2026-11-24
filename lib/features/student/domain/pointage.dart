/// Ticket délivré par `scanner_qr` (étape 1), valable 2 minutes.
class TicketPointage {
  const TicketPointage({
    required this.ticketId,
    required this.expireA,
    required this.visageObligatoire,
    required this.coursNom,
    required this.salle,
  });

  final String ticketId;
  final DateTime expireA;
  final bool visageObligatoire;
  final String coursNom;
  final String salle;

  factory TicketPointage.fromMap(Map<String, dynamic> m) => TicketPointage(
        ticketId: m['ticket_id'] as String,
        // Horloge locale : 2 min à partir de maintenant (le serveur fait foi).
        expireA: DateTime.now().add(const Duration(minutes: 2)),
        visageObligatoire: (m['visage_obligatoire'] ?? true) as bool,
        coursNom: (m['cours_nom'] ?? '') as String,
        salle: (m['salle'] ?? '') as String,
      );
}

/// Étape où le pointage a échoué.
enum EtapePointage { scan, validation }

/// Résultat affiché sur les écrans « Présence validée » / « Pointage refusé ».
class ResultatPointage {
  const ResultatPointage({
    required this.ok,
    this.code,
    this.etape = EtapePointage.validation,
    this.coursNom = '',
    this.salle = '',
    this.heure,
    this.visageVerifie = true,
  });

  final bool ok;
  final String? code;
  final EtapePointage etape;
  final String coursNom;
  final String salle;
  final DateTime? heure;
  final bool visageVerifie;

  /// Lignes « QR code / Visage / Vivacité » des maquettes.
  List<(String, String)> get lignes {
    if (ok) {
      return [
        ('QR code', 'Valide'),
        if (visageVerifie) ('Visage', 'Reconnu'),
        if (visageVerifie) ('Vivacité', 'Confirmée'),
      ];
    }
    final scan = etape == EtapePointage.scan;
    final qr = switch (code) {
      'qr_expire' => 'Expiré',
      'qr_invalide' => 'Invalide',
      'ticket_expire' || 'ticket_deja_utilise' || 'ticket_invalide' => 'À rescanner',
      'seance_cloturee' => 'Séance clôturée',
      'hors_fenetre' => 'Hors fenêtre',
      'seance_non_ouverte' => 'Pas encore ouvert',
      'deja_pointe' => 'Déjà pointé',
      'non_inscrit' => 'Non inscrit',
      _ => 'Valide',
    };
    final visage = switch (code) {
      'visage_non_reconnu' => 'Non reconnu',
      'visage_non_enregistre' => 'Non enregistré',
      'aucun_visage' => 'Non détecté',
      'plusieurs_visages' => 'Plusieurs visages',
      _ => scan ? 'Non vérifié' : (code == 'vivacite_echouee' ? 'Non vérifié' : 'Reconnu'),
    };
    return [
      ('QR code', qr),
      ('Visage', visage),
      if (code == 'vivacite_echouee') ('Vivacité', 'Échouée'),
    ];
  }

  /// Erreurs pour lesquelles « Réessayer » doit relancer le scan du QR.
  bool get doitRescanner => etape == EtapePointage.scan ||
      const {'ticket_expire', 'ticket_deja_utilise', 'ticket_invalide', 'trop_de_tentatives'}
          .contains(code);
}
