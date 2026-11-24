import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:classcheck/core/models/sprint2.dart';
import 'package:classcheck/core/utils/formatters.dart';

/// Génération des exports (D-Export). Fonctions pures, testées unitairement.
class ExportStats {
  ExportStats._();

  static String _pct(double t) => '${(t * 100).round()} %';

  /// Échappe une cellule CSV (séparateur « ; », guillemets doublés).
  static String cellule(Object? v) {
    final s = '${v ?? ''}';
    if (s.contains(';') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// CSV « données brutes pour Excel » : séparateur `;` et BOM UTF-8 pour
  /// que les accents s'affichent correctement dans Excel en français.
  static String csv(StatsPresences s, {required String periode}) {
    final b = StringBuffer('﻿');
    void ligne(List<Object?> c) => b.writeln(c.map(cellule).join(';'));
    ligne(['ClassCheck - export des statistiques', periode]);
    ligne(['Taux de présence', _pct(s.taux), 'Séances', s.nbSeances, 'Retards', s.retards]);
    b.writeln();
    ligne(['Cours', 'Séances', 'Taux de présence']);
    for (final c in s.parCours) {
      ligne([c.libelle, c.seances, _pct(c.taux)]);
    }
    b.writeln();
    ligne(['Étudiant', 'Classe', 'Présences', 'Retards', 'Absences', 'Absences non justifiées', 'Taux']);
    for (final e in s.etudiants) {
      ligne([e.nom, e.classe, e.presents, e.retards, e.absences, e.absencesNonJustifiees, _pct(e.taux)]);
    }
    return b.toString();
  }

  /// PDF « rapport mis en page, prêt à imprimer ».
  static Future<Uint8List> pdf(StatsPresences s,
      {required String periode, List<EtudiantARisque> aRisque = const []}) async {
    final doc = pw.Document(title: 'ClassCheck - statistiques', author: 'ClassCheck');
    final violet = PdfColor.fromHex('#B9A5E3');
    final lavande = PdfColor.fromHex('#D9CCF0');
    pw.Widget tableau(List<String> entetes, List<List<String>> lignes) => pw.TableHelper.fromTextArray(
          headers: entetes,
          data: lignes,
          headerDecoration: pw.BoxDecoration(color: lavande),
          headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Text('Rapport d\'assiduité', style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text('Période : $periode · généré le ${Fmt.jourCourt(DateTime.now())} ${DateTime.now().year}'),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: violet, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
              pw.Text('Présence : ${_pct(s.taux)}', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('Séances : ${s.nbSeances}', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('Retards : ${s.retards}', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('À risque : ${{for (final r in aRisque) r.etudiantId}.length}',
                  style: const pw.TextStyle(fontSize: 14)),
            ]),
          ),
          pw.SizedBox(height: 18),
          pw.Text('Par cours', style: const pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          tableau(['Cours', 'Séances', 'Présence'],
              [for (final c in s.parCours) [c.libelle, '${c.seances}', _pct(c.taux)]]),
          if (aRisque.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('Étudiants à risque', style: const pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            tableau(['Étudiant', 'Classe', 'Cours', 'Absences'], [
              for (final r in aRisque) [r.nom, r.classe, r.cours, '${r.absences} / ${r.seuil}'],
            ]),
          ],
          pw.SizedBox(height: 18),
          pw.Text('Par étudiant', style: const pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          tableau(['Étudiant', 'Classe', 'Prés.', 'Ret.', 'Abs.', 'Taux'], [
            for (final e in s.etudiants)
              [e.nom, e.classe, '${e.presents}', '${e.retards}', '${e.absences}', _pct(e.taux)],
          ]),
        ],
      ),
    );
    return doc.save();
  }
}
