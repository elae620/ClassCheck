import 'package:classcheck/core/models/presence.dart';
import 'package:classcheck/core/models/seance.dart';

DateTime? _ts(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
String? _nom(Object? m) => (m is Map) ? m['nom'] as String? : null;

/// Ligne de `reclamations` (avec la présence contestée et sa séance).
class Reclamation {
  const Reclamation({
    required this.id,
    required this.presenceId,
    required this.etudiantId,
    required this.motif,
    required this.statut,
    required this.creeA,
    this.justificatif,
    this.avisEnseignant,
    this.commentaireDecision,
    this.decisionPar,
    this.decisionParNom,
    this.decisionParRole,
    this.etudiantNom,
    this.traiteA,
    this.presence,
  });

  static const colonnes =
      'id, presence_id, etudiant_id, motif, justificatif_url, statut, avis_enseignant, '
      'commentaire_decision, decision_par, traite_a, created_at, '
      'etudiant:etudiant_id(nom), decideur:decision_par(nom, role), '
      'presence:presence_id(id, seance_id, etudiant_id, statut, methode, pointe_a, justifiee, '
      'seance:seance_id(${Seance.colonnes}))';

  final String id;
  final String presenceId;
  final String etudiantId;
  final String motif;

  /// en_attente | acceptee | refusee | transmise
  final String statut;
  final DateTime creeA;
  final String? justificatif;
  final String? avisEnseignant;
  final String? commentaireDecision;
  final String? decisionPar;
  final String? decisionParNom;

  /// enseignant | directeur (auteur de la dernière décision).
  final String? decisionParRole;
  final String? etudiantNom;
  final DateTime? traiteA;
  final Presence? presence;

  Seance? get seance => presence?.seance;
  bool get enCours => statut == 'en_attente' || statut == 'transmise';

  /// Un recours est possible après un refus de l'enseignant (pas du directeur).
  bool get recoursPossible => statut == 'refusee' && decisionParRole != 'directeur';

  factory Reclamation.fromMap(Map<String, dynamic> m) {
    final p = m['presence'];
    return Reclamation(
      id: m['id'] as String,
      presenceId: m['presence_id'] as String,
      etudiantId: m['etudiant_id'] as String,
      motif: m['motif'] as String,
      statut: m['statut'] as String,
      creeA: _ts(m['created_at']) ?? DateTime.now(),
      justificatif: m['justificatif_url'] as String?,
      avisEnseignant: m['avis_enseignant'] as String?,
      commentaireDecision: m['commentaire_decision'] as String?,
      decisionPar: m['decision_par'] as String?,
      decisionParNom: _nom(m['decideur']),
      decisionParRole: (m['decideur'] as Map?)?['role'] as String?,
      etudiantNom: _nom(m['etudiant']),
      traiteA: _ts(m['traite_a']),
      presence: p is Map ? Presence.fromMap(p.cast<String, dynamic>()) : null,
    );
  }

  String get libelleStatut => switch (statut) {
        'en_attente' => 'En attente',
        'acceptee' => 'Acceptée',
        'refusee' => 'Refusée',
        'transmise' => 'Transmise au directeur',
        _ => statut,
      };
}

/// Ligne de `auto_declarations`.
class AutoDeclaration {
  const AutoDeclaration({
    required this.id,
    required this.seanceId,
    required this.etudiantId,
    required this.type,
    required this.motif,
    required this.statut,
    required this.creeA,
    this.etudiantNom,
    this.seance,
  });

  static const colonnes = 'id, seance_id, etudiant_id, type, motif, statut, created_at, '
      'etudiant:etudiant_id(nom), seance:seance_id(${Seance.colonnes})';

  final String id;
  final String seanceId;
  final String etudiantId;

  /// retard | absence_justifiee
  final String type;
  final String motif;

  /// en_attente | validee | refusee
  final String statut;
  final DateTime creeA;
  final String? etudiantNom;
  final Seance? seance;

  String get libelleType => type == 'retard' ? 'Retard' : 'Absence';

  factory AutoDeclaration.fromMap(Map<String, dynamic> m) {
    final s = m['seance'];
    return AutoDeclaration(
      id: m['id'] as String,
      seanceId: m['seance_id'] as String,
      etudiantId: m['etudiant_id'] as String,
      type: m['type'] as String,
      motif: m['motif'] as String,
      statut: m['statut'] as String,
      creeA: _ts(m['created_at']) ?? DateTime.now(),
      etudiantNom: _nom(m['etudiant']),
      seance: s is Map ? Seance.fromMap(s.cast<String, dynamic>()) : null,
    );
  }
}

/// Ligne de `notifications`.
class NotificationApp {
  const NotificationApp({
    required this.id,
    required this.titre,
    required this.message,
    required this.lu,
    required this.creeA,
    this.type,
  });

  final String id;
  final String titre;
  final String message;
  final bool lu;
  final DateTime creeA;

  /// seuil | reclamation | auto_declaration
  final String? type;

  factory NotificationApp.fromMap(Map<String, dynamic> m) => NotificationApp(
        id: m['id'] as String,
        titre: m['titre'] as String,
        message: m['message'] as String,
        lu: (m['lu'] ?? false) as bool,
        creeA: _ts(m['created_at']) ?? DateTime.now(),
        type: m['type'] as String?,
      );
}

/// Ligne du journal d'audit.
class EntreeAudit {
  const EntreeAudit({
    required this.id,
    required this.action,
    required this.creeA,
    required this.details,
    this.acteurNom,
    this.motif,
  });

  final int id;
  final String action;
  final DateTime creeA;
  final Map<String, dynamic> details;
  final String? acteurNom;
  final String? motif;

  factory EntreeAudit.fromMap(Map<String, dynamic> m) => EntreeAudit(
        id: (m['id'] as num).toInt(),
        action: m['action'] as String,
        creeA: _ts(m['created_at']) ?? DateTime.now(),
        details: ((m['details'] as Map?) ?? const {}).cast<String, dynamic>(),
        acteurNom: _nom(m['acteur']),
        motif: m['motif'] as String?,
      );

  bool get estCorrection => action == 'correction_presence';
  bool get estDecision => action.startsWith('decision_') || action == 'regles_modifiees';

  String get libelle => switch (action) {
        'correction_presence' => 'Correction de présence',
        'decision_reclamation' => 'Décision de réclamation',
        'decision_auto_declaration' => 'Décision d\'auto-déclaration',
        'pointage_valide' => 'Pointage validé',
        'pointage_refuse' => 'Pointage refusé',
        'seance_ouverte' => 'Séance ouverte',
        'seance_cloturee' => 'Séance clôturée',
        'visage_enregistre' => 'Visage enregistré',
        'visage_reenregistre' => 'Visage réenregistré',
        'visage_refuse' => 'Visage refusé',
        'regles_modifiees' => 'Règles modifiées',
        'compte_modifie' => 'Compte modifié',
        'compte_cree' => 'Compte créé',
        _ => action,
      };
}

/// Ligne par étudiant renvoyée par `stats_presences`.
class StatEtudiant {
  const StatEtudiant({
    required this.id,
    required this.nom,
    required this.classe,
    required this.presents,
    required this.retards,
    required this.absences,
    required this.absencesNonJustifiees,
    required this.total,
  });

  final String id;
  final String nom;
  final String classe;
  final int presents;
  final int retards;
  final int absences;
  final int absencesNonJustifiees;
  final int total;

  double get taux => total == 0 ? 1 : (presents + retards) / total;

  factory StatEtudiant.fromMap(Map<String, dynamic> m) => StatEtudiant(
        id: m['etudiant_id'] as String,
        nom: (m['nom'] ?? 'Étudiant') as String,
        classe: (m['classe'] ?? '') as String,
        presents: (m['presents'] as num).toInt(),
        retards: (m['retards'] as num).toInt(),
        absences: (m['absences'] as num).toInt(),
        absencesNonJustifiees: (m['absences_nj'] as num).toInt(),
        total: (m['total'] as num).toInt(),
      );
}

/// Taux de présence d'un groupe (classe ou cours).
class StatGroupe {
  const StatGroupe({required this.libelle, required this.taux, this.id, this.seances = 0});
  final String? id;
  final String libelle;
  final double taux;
  final int seances;
}

/// Résultat de la RPC `stats_presences`.
class StatsPresences {
  const StatsPresences({
    required this.total,
    required this.taux,
    required this.nbSeances,
    required this.retards,
    required this.parClasse,
    required this.parCours,
    required this.etudiants,
  });

  final int total;
  final double taux;
  final int nbSeances;
  final int retards;
  final List<StatGroupe> parClasse;
  final List<StatGroupe> parCours;
  final List<StatEtudiant> etudiants;

  int get tauxPourcent => (taux * 100).round();

  factory StatsPresences.fromMap(Map<String, dynamic> m) {
    List<Map<String, dynamic>> liste(Object? v) =>
        [for (final e in (v as List? ?? const [])) (e as Map).cast<String, dynamic>()];
    return StatsPresences(
      total: (m['total'] as num? ?? 0).toInt(),
      taux: (m['taux'] as num? ?? 1).toDouble(),
      nbSeances: (m['nb_seances'] as num? ?? 0).toInt(),
      retards: (m['retards'] as num? ?? 0).toInt(),
      parClasse: [
        for (final c in liste(m['par_classe']))
          StatGroupe(libelle: c['classe'] as String, taux: (c['taux'] as num).toDouble()),
      ],
      parCours: [
        for (final c in liste(m['par_cours']))
          StatGroupe(
            id: c['cours_id'] as String?,
            libelle: '${c['cours']} · ${c['classe']}',
            taux: (c['taux'] as num).toDouble(),
            seances: (c['seances'] as num? ?? 0).toInt(),
          ),
      ],
      etudiants: [for (final e in liste(m['etudiants'])) StatEtudiant.fromMap(e)],
    );
  }
}

/// Ligne de `etudiants_a_risque()`.
class EtudiantARisque {
  const EtudiantARisque({
    required this.etudiantId,
    required this.nom,
    required this.classe,
    required this.cours,
    required this.absences,
    required this.seuil,
  });

  final String etudiantId;
  final String nom;
  final String classe;
  final String cours;
  final int absences;
  final int seuil;

  bool get depasse => absences >= seuil;

  factory EtudiantARisque.fromMap(Map<String, dynamic> m) => EtudiantARisque(
        etudiantId: m['etudiant_id'] as String,
        nom: (m['nom'] ?? '') as String,
        classe: (m['classe'] ?? '') as String,
        cours: (m['cours'] ?? '') as String,
        absences: (m['absences'] as num).toInt(),
        seuil: (m['seuil'] as num).toInt(),
      );
}
