enum Role {
  etudiant('etudiant', 'Étudiant', '/etudiant'),
  enseignant('enseignant', 'Enseignant', '/enseignant'),
  directeur('directeur', 'Directeur', '/directeur');

  const Role(this.valeur, this.libelle, this.accueil);

  final String valeur;
  final String libelle;

  /// Route d'accueil du rôle.
  final String accueil;

  static Role depuis(String? v) =>
      Role.values.firstWhere((r) => r.valeur == v, orElse: () => Role.etudiant);
}

/// Profil applicatif (table `profils`). L'embedding du visage n'est
/// jamais lu par l'application : seul le nombre de captures l'est.
class Profil {
  const Profil({
    required this.id,
    required this.nom,
    required this.email,
    required this.role,
    this.classe,
    this.nbCaptures = 0,
    this.actif = true,
  });

  /// Colonnes autorisées en lecture (la colonne `face_embedding` est interdite).
  static const colonnes = 'id, nom, email, role, classe, nb_captures, actif';

  final String id;
  final String nom;
  final String email;
  final Role role;
  final String? classe;
  final int nbCaptures;
  final bool actif;

  bool get visageEnregistre => nbCaptures >= 5;

  /// « DSI 2 · Étudiant »
  String get sousTitre =>
      [if (classe != null && classe!.isNotEmpty) classe!, role.libelle].join(' · ');

  factory Profil.fromMap(Map<String, dynamic> m) => Profil(
        id: m['id'] as String,
        nom: (m['nom'] ?? '') as String,
        email: (m['email'] ?? '') as String,
        role: Role.depuis(m['role'] as String?),
        classe: m['classe'] as String?,
        nbCaptures: (m['nb_captures'] ?? 0) as int,
        actif: (m['actif'] ?? true) as bool,
      );
}
