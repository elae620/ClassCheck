/// Petites fonctions de mise en forme (dates courtes « 12 nov », heures, noms).
class Fmt {
  Fmt._();

  static const _mois = [
    'janv', 'févr', 'mars', 'avr', 'mai', 'juin',
    'juil', 'août', 'sept', 'oct', 'nov', 'déc',
  ];
  static const _moisCap = [
    'Janv', 'Févr', 'Mars', 'Avr', 'Mai', 'Juin',
    'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc',
  ];
  static const joursCourts = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  /// 10:03
  static String heure(DateTime d) => '${_pad2(d.hour)}:${_pad2(d.minute)}';

  /// « 10:00:00 » (Postgres) → « 10:00 »
  static String heureSql(String t) => t.length >= 5 ? t.substring(0, 5) : t;

  /// 10:00 – 12:00
  static String plage(String debut, String fin) => '${heureSql(debut)} – ${heureSql(fin)}';

  /// 12 nov
  static String jourCourt(DateTime d) => '${_pad2(d.day)} ${_mois[d.month - 1]}';

  /// Sept
  static String moisCourt(int mois) => _moisCap[mois - 1];

  /// 0:18
  static String compteARebours(int secondes) {
    final s = secondes < 0 ? 0 : secondes;
    return '${s ~/ 60}:${_pad2(s % 60)}';
  }

  /// 2026-11-20 (format Postgres `date`)
  static String dateSql(DateTime d) => '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';

  /// « Ali Ben Salah » → « Ali B. »
  static String nomCourt(String nom) {
    final parties = nom.trim().split(RegExp(r'\s+'));
    if (parties.length < 2) return nom.trim();
    final second = parties[1];
    return second.endsWith('.') ? '${parties[0]} $second' : '${parties[0]} ${second[0]}.';
  }

  /// « Ali Ben Salah » → « Ali »
  static String prenom(String nom) => nom.trim().split(RegExp(r'\s+')).first;

  static String initiale(String nom) =>
      nom.trim().isEmpty ? '?' : nom.trim()[0].toUpperCase();

  /// Normalise une classe saisie : « dsi2 », « Dsi  2 » → « DSI 2 ».
  static String normaliserClasse(String saisie) {
    var c = saisie.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    c = c.replaceAllMapped(RegExp(r'([A-Z])(\d)'), (m) => '${m[1]} ${m[2]}');
    return c;
  }

  /// Lundi de la semaine contenant [d] (à minuit).
  static DateTime lundi(DateTime d) {
    final jour = DateTime(d.year, d.month, d.day);
    return jour.subtract(Duration(days: jour.weekday - 1));
  }

  static DateTime aujourdhui() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static bool memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
