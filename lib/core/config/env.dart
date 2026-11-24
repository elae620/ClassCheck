import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Configuration Supabase. Aucune clé n'est écrite dans le code source.
///
/// Ordre de lecture :
///  1. `--dart-define-from-file=dart_defines.json` (compilation) ;
///  2. à défaut, le fichier local `assets/config/supabase.json` (ignoré par git),
///     pour que l'application démarre aussi avec le bouton Run par défaut
///     d'Android Studio ou un simple `flutter run`.
class Env {
  Env._();

  static const _urlCompilee = String.fromEnvironment('SUPABASE_URL');
  static const _cleCompilee = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Fichier local facultatif (même format que `dart_defines.json`).
  static const fichierLocal = 'assets/config/supabase.json';

  static String supabaseUrl = _urlCompilee;
  static String supabaseAnonKey = _cleCompilee;

  static bool get estConfigure => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Complète la configuration à partir du fichier local si nécessaire.
  static Future<void> charger({AssetBundle? bundle}) async {
    if (estConfigure) return;
    try {
      final texte = await (bundle ?? rootBundle).loadString(fichierLocal);
      final m = jsonDecode(texte) as Map<String, dynamic>;
      supabaseUrl = (m['SUPABASE_URL'] as String? ?? '').trim();
      supabaseAnonKey = (m['SUPABASE_ANON_KEY'] as String? ?? '').trim();
    } catch (e) {
      debugPrint('Configuration locale absente ($fichierLocal) : $e');
    }
  }
}
