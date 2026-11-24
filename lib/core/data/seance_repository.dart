import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:classcheck/core/models/seance.dart';
import 'package:classcheck/core/supabase/supabase_providers.dart';
import 'package:classcheck/core/utils/formatters.dart';

/// Accès aux séances. La RLS filtre automatiquement :
/// étudiant → sa classe, enseignant → ses cours, directeur → tout.
class SeanceRepository {
  SeanceRepository(this._db);
  final SupabaseClient _db;

  Future<List<Seance>> seancesEntre(DateTime du, DateTime au) async {
    final lignes = await _db
        .from('seances')
        .select(Seance.colonnes)
        .gte('date', Fmt.dateSql(du))
        .lte('date', Fmt.dateSql(au))
        .order('date', ascending: true)
        .order('heure_debut', ascending: true);
    return lignes.map(Seance.fromMap).toList();
  }

  Future<Seance> seance(String id) async {
    final ligne = await _db.from('seances').select(Seance.colonnes).eq('id', id).single();
    return Seance.fromMap(ligne);
  }

  Future<Map<String, dynamic>> regles() async {
    return _db.from('regles').select().eq('id', 1).single();
  }
}

final seanceRepositoryProvider =
    Provider<SeanceRepository>((ref) => SeanceRepository(ref.watch(supabaseProvider)));

/// Séances du jour (accueil étudiant et enseignant).
final seancesDuJourProvider = FutureProvider.autoDispose<List<Seance>>((ref) {
  ref.watch(currentUserIdProvider);
  final j = Fmt.aujourdhui();
  return ref.watch(seanceRepositoryProvider).seancesEntre(j, j);
});

/// Séances d'une semaine (clé : le lundi).
final seancesSemaineProvider =
    FutureProvider.autoDispose.family<List<Seance>, DateTime>((ref, lundi) {
  ref.watch(currentUserIdProvider);
  return ref
      .watch(seanceRepositoryProvider)
      .seancesEntre(lundi, lundi.add(const Duration(days: 6)));
});

final seanceProvider = FutureProvider.autoDispose.family<Seance, String>(
  (ref, id) => ref.watch(seanceRepositoryProvider).seance(id),
);

/// Règles de l'établissement (ligne unique de la table `regles`).
class Regles {
  const Regles({
    this.seuilExclusion = 5,
    this.fenetrePointage = 15,
    this.renouvellementQr = 30,
    this.visageObligatoire = true,
    this.seuilVisage = 1.0,
    this.votesVisage = 2,
  });

  final int seuilExclusion;
  final int fenetrePointage;
  final int renouvellementQr;
  final bool visageObligatoire;
  final double seuilVisage;

  /// Nombre de captures de référence (sur 5) qui doivent reconnaître le visage.
  final int votesVisage;

  Regles copier({
    int? seuilExclusion,
    int? fenetrePointage,
    int? renouvellementQr,
    bool? visageObligatoire,
    double? seuilVisage,
    int? votesVisage,
  }) =>
      Regles(
        seuilExclusion: seuilExclusion ?? this.seuilExclusion,
        fenetrePointage: fenetrePointage ?? this.fenetrePointage,
        renouvellementQr: renouvellementQr ?? this.renouvellementQr,
        visageObligatoire: visageObligatoire ?? this.visageObligatoire,
        seuilVisage: seuilVisage ?? this.seuilVisage,
        votesVisage: votesVisage ?? this.votesVisage,
      );

  factory Regles.fromMap(Map<String, dynamic> m) => Regles(
        seuilExclusion: (m['seuil_exclusion'] ?? 5) as int,
        fenetrePointage: (m['fenetre_pointage'] ?? 15) as int,
        renouvellementQr: (m['renouvellement_qr'] ?? 30) as int,
        visageObligatoire: (m['visage_obligatoire'] ?? true) as bool,
        seuilVisage: ((m['seuil_visage'] ?? 1.0) as num).toDouble(),
        votesVisage: (m['votes_visage'] ?? 2) as int,
      );
}

final reglesProvider = FutureProvider<Regles>((ref) async {
  ref.watch(currentUserIdProvider);
  try {
    return Regles.fromMap(await ref.watch(seanceRepositoryProvider).regles());
  } catch (_) {
    return const Regles();
  }
});
