import 'package:flutter_test/flutter_test.dart';

import 'package:classcheck/core/models/sprint2.dart';
import 'package:classcheck/features/director/domain/export_stats.dart';

/// Réponse type de la RPC `stats_presences`.
final _statsJson = <String, dynamic>{
  'total': 10,
  'taux': 0.8,
  'nb_seances': 4,
  'retards': 1,
  'par_classe': [
    {'classe': 'DSI 2', 'taux': 0.8},
  ],
  'par_cours': [
    {'cours_id': 'c1', 'cours': 'Flutter', 'classe': 'DSI 2', 'seances': 4, 'taux': 0.8},
  ],
  'etudiants': [
    {
      'etudiant_id': 'e1',
      'nom': 'Omar Haddad',
      'classe': 'DSI 2',
      'presents': 2,
      'retards': 0,
      'absences': 2,
      'absences_nj': 1,
      'total': 4,
    },
    {
      'etudiant_id': 'e2',
      'nom': 'Ali; "Ben" Salah',
      'classe': 'DSI 2',
      'presents': 3,
      'retards': 1,
      'absences': 0,
      'absences_nj': 0,
      'total': 4,
    },
  ],
};

void main() {
  group('Statistiques', () {
    final s = StatsPresences.fromMap(_statsJson);

    test('lecture de la RPC stats_presences', () {
      expect(s.tauxPourcent, 80);
      expect(s.nbSeances, 4);
      expect(s.parCours.single.libelle, 'Flutter · DSI 2');
      expect(s.etudiants.first.absencesNonJustifiees, 1);
    });

    test('taux d\'un étudiant = (présents + retards) / total', () {
      expect(s.etudiants[0].taux, 0.5);
      expect(s.etudiants[1].taux, 1.0);
    });

    test('étudiant à risque : seuil atteint ou proche', () {
      const r = EtudiantARisque(
          etudiantId: 'e1', nom: 'Omar', classe: 'DSI 2', cours: 'Flutter', absences: 5, seuil: 5);
      const proche = EtudiantARisque(
          etudiantId: 'e1', nom: 'Omar', classe: 'DSI 2', cours: 'BD', absences: 4, seuil: 5);
      expect(r.depasse, isTrue);
      expect(proche.depasse, isFalse);
    });
  });

  group('Export CSV', () {
    final csv = ExportStats.csv(StatsPresences.fromMap(_statsJson), periode: 'Mois');

    test('BOM UTF-8 et séparateur point-virgule (Excel FR)', () {
      expect(csv.startsWith('﻿'), isTrue);
      expect(csv, contains('Taux de présence;80 %'));
      expect(csv, contains('Flutter · DSI 2;4;80 %'));
    });

    test('cellules avec ; ou guillemets correctement échappées', () {
      expect(csv, contains('"Ali; ""Ben"" Salah";DSI 2;3;1;0;0;100 %'));
      expect(ExportStats.cellule('simple'), 'simple');
    });

    test('PDF généré (en-tête %PDF)', () async {
      final octets = await ExportStats.pdf(StatsPresences.fromMap(_statsJson), periode: 'Mois');
      expect(String.fromCharCodes(octets.take(4)), '%PDF');
    });
  });

  group('Réclamations', () {
    Map<String, dynamic> recl(String statut, {String? role}) => {
          'id': 'r1',
          'presence_id': 'p1',
          'etudiant_id': 'e1',
          'motif': 'Malade',
          'statut': statut,
          'created_at': '2026-11-20T09:00:00Z',
          'decideur': role == null ? null : {'nom': 'X', 'role': role},
        };

    test('statuts « en cours »', () {
      expect(Reclamation.fromMap(recl('en_attente')).enCours, isTrue);
      expect(Reclamation.fromMap(recl('transmise')).enCours, isTrue);
      expect(Reclamation.fromMap(recl('acceptee')).enCours, isFalse);
    });

    test('recours possible seulement après un refus de l\'enseignant', () {
      expect(Reclamation.fromMap(recl('refusee', role: 'enseignant')).recoursPossible, isTrue);
      expect(Reclamation.fromMap(recl('refusee', role: 'directeur')).recoursPossible, isFalse);
      expect(Reclamation.fromMap(recl('acceptee', role: 'enseignant')).recoursPossible, isFalse);
    });
  });

  group('Journal d\'audit', () {
    EntreeAudit e(String action) => EntreeAudit.fromMap({
          'id': 1,
          'action': action,
          'created_at': '2026-11-20T09:00:00Z',
          'details': {'ancien': 'absent', 'nouveau': 'present'},
          'motif': 'caméra en panne',
        });

    test('filtres Corrections / Décisions', () {
      expect(e('correction_presence').estCorrection, isTrue);
      expect(e('decision_reclamation').estDecision, isTrue);
      expect(e('pointage_valide').estDecision, isFalse);
      expect(e('correction_presence').libelle, 'Correction de présence');
    });
  });
}
