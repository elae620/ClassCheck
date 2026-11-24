/// Validateurs de formulaires partagés.
String? validerEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'E-mail requis';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'E-mail invalide';
  return null;
}

String? validerMotDePasse(String? v) {
  final s = v ?? '';
  if (s.length < 8) return '8 caractères minimum';
  return null;
}

String? validerRequis(String? v, [String champ = 'Ce champ']) {
  if ((v ?? '').trim().isEmpty) return '$champ est obligatoire';
  return null;
}

String? validerClasse(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Classe requise';
  if (!RegExp(r'^[A-Za-z]+\s*\d+$').hasMatch(s)) return 'Format attendu : DSI 2';
  return null;
}
