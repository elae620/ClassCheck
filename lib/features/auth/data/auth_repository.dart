import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:classcheck/core/supabase/supabase_providers.dart';
import 'package:classcheck/features/auth/domain/profil.dart';

class AuthRepository {
  AuthRepository(this._db);
  final SupabaseClient _db;

  Future<void> connexion(String email, String motDePasse) async {
    await _db.auth.signInWithPassword(email: email.trim(), password: motDePasse);
  }

  /// Le profil est créé côté serveur par le trigger `handle_new_user`
  /// à partir des métadonnées (nom, rôle, classe).
  Future<AuthResponse> inscription({
    required String email,
    required String motDePasse,
    required String nom,
    required Role role,
    String? classe,
  }) {
    return _db.auth.signUp(
      email: email.trim(),
      password: motDePasse,
      data: {
        'nom': nom.trim(),
        'role': role.valeur,
        if (classe != null && classe.isNotEmpty) 'classe': classe,
      },
    );
  }

  Future<void> motDePasseOublie(String email) =>
      _db.auth.resetPasswordForEmail(email.trim());

  Future<void> deconnexion() => _db.auth.signOut();

  Future<Profil?> profil(String id) async {
    final ligne =
        await _db.from('profils').select(Profil.colonnes).eq('id', id).maybeSingle();
    return ligne == null ? null : Profil.fromMap(ligne);
  }

  /// Seul le `nom` est modifiable par l'utilisateur (droits SQL par colonne) :
  /// la classe est gérée par le directeur, sinon un étudiant pourrait lire
  /// les données d'une autre classe.
  Future<void> modifierProfil(String id, {required String nom}) async {
    await _db.from('profils').update({'nom': nom.trim()}).eq('id', id);
  }
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseProvider)));

/// Profil de l'utilisateur connecté (null si déconnecté).
final profilProvider = FutureProvider<Profil?>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  return ref.watch(authRepositoryProvider).profil(uid);
});

/// Vrai pendant une connexion/inscription : le routeur ne redirige pas
/// tant que l'écran n'a pas fini ses vérifications.
final authBusyProvider = StateProvider<bool>((ref) => false);
