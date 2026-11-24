import 'package:classcheck/core/models/seance.dart';

/// Ligne de la table `presences`.
class Presence {
  const Presence({
    required this.id,
    required this.seanceId,
    required this.etudiantId,
    required this.statut,
    required this.methode,
    this.pointeA,
    this.seance,
    this.justifiee = false,
  });

  final String id;
  final String seanceId;
  final String etudiantId;

  /// present | absent | retard
  final String statut;

  /// qr_visage | qr | manuel | auto_cloture | auto_declaration
  final String methode;
  final DateTime? pointeA;
  final Seance? seance;

  /// Absence justifiée (réclamation acceptée, auto-déclaration validée).
  final bool justifiee;

  factory Presence.fromMap(Map<String, dynamic> m) {
    final s = m['seance'];
    return Presence(
      id: m['id'] as String,
      seanceId: m['seance_id'] as String,
      etudiantId: m['etudiant_id'] as String,
      statut: m['statut'] as String,
      methode: m['methode'] as String,
      pointeA: m['pointe_a'] == null ? null : DateTime.parse(m['pointe_a'] as String).toLocal(),
      seance: s is Map ? Seance.fromMap(s.cast<String, dynamic>()) : null,
      justifiee: (m['justifiee'] ?? false) as bool,
    );
  }

  bool get estPresent => statut == 'present' || statut == 'retard';

  String get libelleMethode => switch (methode) {
        'qr_visage' => 'QR + visage',
        'qr' => 'QR',
        'manuel' => 'Correction',
        'auto_cloture' => 'Clôture',
        'auto_declaration' => 'Auto-déclaration',
        _ => methode,
      };
}
