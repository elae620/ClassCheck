import 'package:classcheck/core/utils/formatters.dart';

enum EtatSeance { aVenir, enCours, terminee }

/// Séance d'un cours (table `seances` + jointure `cours` et enseignant).
class Seance {
  const Seance({
    required this.id,
    required this.coursId,
    required this.coursNom,
    required this.coursNomCourt,
    required this.classe,
    required this.salle,
    required this.date,
    required this.heureDebut,
    required this.heureFin,
    required this.statut,
    this.ouverteA,
    this.fenetreMinutes,
    this.visageObligatoire = true,
    this.clotureeA,
    this.enseignantNom,
  });

  /// Colonnes à sélectionner pour construire une [Seance].
  static const colonnes =
      'id, date, heure_debut, heure_fin, salle, statut, ouverte_a, fenetre_minutes, '
      'visage_obligatoire, cloturee_a, '
      'cours:cours_id(id, nom, nom_court, classe, salle, enseignant:enseignant_id(nom))';

  final String id;
  final String coursId;
  final String coursNom;
  final String coursNomCourt;
  final String classe;
  final String salle;
  final DateTime date;
  final String heureDebut;
  final String heureFin;

  /// planifiee | ouverte | cloturee
  final String statut;
  final DateTime? ouverteA;
  final int? fenetreMinutes;
  final bool visageObligatoire;
  final DateTime? clotureeA;
  final String? enseignantNom;

  factory Seance.fromMap(Map<String, dynamic> m) {
    final cours = (m['cours'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ens = (cours['enseignant'] as Map?)?.cast<String, dynamic>();
    DateTime? ts(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
    return Seance(
      id: m['id'] as String,
      coursId: (cours['id'] ?? '') as String,
      coursNom: (cours['nom'] ?? 'Cours') as String,
      coursNomCourt: (cours['nom_court'] ?? cours['nom'] ?? 'Cours') as String,
      classe: (cours['classe'] ?? '') as String,
      salle: (m['salle'] ?? cours['salle'] ?? '—') as String,
      date: DateTime.parse(m['date'] as String),
      heureDebut: m['heure_debut'] as String,
      heureFin: m['heure_fin'] as String,
      statut: m['statut'] as String,
      ouverteA: ts(m['ouverte_a']),
      fenetreMinutes: m['fenetre_minutes'] as int?,
      visageObligatoire: (m['visage_obligatoire'] ?? true) as bool,
      clotureeA: ts(m['cloturee_a']),
      enseignantNom: ens?['nom'] as String?,
    );
  }

  DateTime _aHeure(String t) {
    final p = t.split(':');
    return DateTime(date.year, date.month, date.day, int.parse(p[0]), int.parse(p[1]));
  }

  DateTime get debut => _aHeure(heureDebut);
  DateTime get fin => _aHeure(heureFin);
  String get plage => Fmt.plage(heureDebut, heureFin);
  bool get estOuverte => statut == 'ouverte';
  bool get estCloturee => statut == 'cloturee';
  bool get estAujourdhui => Fmt.memeJour(date, DateTime.now());

  /// Fin de la fenêtre de pointage (null si la séance n'est pas ouverte).
  DateTime? get finFenetre =>
      ouverteA?.add(Duration(minutes: fenetreMinutes ?? 15));

  bool get pointageOuvert =>
      estOuverte && finFenetre != null && DateTime.now().isBefore(finFenetre!);

  EtatSeance etat([DateTime? maintenant]) {
    final n = maintenant ?? DateTime.now();
    if (estCloturee || n.isAfter(fin)) return EtatSeance.terminee;
    if (estOuverte || !n.isBefore(debut)) return EtatSeance.enCours;
    return EtatSeance.aVenir;
  }

  /// « Flutter · DSI 2 »
  String get coursEtClasse => '$coursNomCourt · $classe';
}
