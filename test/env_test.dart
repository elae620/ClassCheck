import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classcheck/core/config/env.dart';

/// Bundle d'assets en mémoire pour simuler `assets/config/supabase.json`.
class _Bundle extends CachingAssetBundle {
  _Bundle(this.fichiers);
  final Map<String, String> fichiers;

  @override
  Future<ByteData> load(String key) async {
    final t = fichiers[key];
    if (t == null) throw StateError('Asset absent : $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(t)));
  }
}

void main() {
  setUp(() {
    Env.supabaseUrl = '';
    Env.supabaseAnonKey = '';
  });

  test('sans --dart-define : clés lues dans assets/config/supabase.json', () async {
    await Env.charger(bundle: _Bundle({
      Env.fichierLocal: '{"SUPABASE_URL": "https://x.supabase.co", "SUPABASE_ANON_KEY": "sb_publishable_test"}',
    }));
    expect(Env.estConfigure, isTrue);
    expect(Env.supabaseUrl, 'https://x.supabase.co');
  });

  test('fichier absent : configuration manquante, sans plantage', () async {
    await Env.charger(bundle: _Bundle({}));
    expect(Env.estConfigure, isFalse);
  });
}
