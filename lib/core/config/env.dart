/// Configuration injectée à la compilation (`--dart-define-from-file=dart_defines.json`).
/// Aucune clé n'est écrite en dur dans le code source.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get estConfigure =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
