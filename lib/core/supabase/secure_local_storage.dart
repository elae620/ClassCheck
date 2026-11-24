import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persistance de la session Supabase dans le stockage sécurisé du téléphone.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage();

  static const _cle = 'classcheck_session';

  final FlutterSecureStorage _stockage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _stockage.containsKey(key: _cle);

  @override
  Future<String?> accessToken() => _stockage.read(key: _cle);

  @override
  Future<void> removePersistedSession() => _stockage.delete(key: _cle);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _stockage.write(key: _cle, value: persistSessionString);
}
