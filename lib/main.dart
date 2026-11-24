import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:classcheck/core/config/env.dart';
import 'package:classcheck/core/router/app_router.dart';
import 'package:classcheck/core/supabase/secure_local_storage.dart';
import 'package:classcheck/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // L'application est conçue en portrait (maquettes mobiles) : cela simplifie
  // aussi la rotation des images envoyées à ML Kit.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('fr_FR');
  Intl.defaultLocale = 'fr_FR';

  if (!Env.estConfigure) {
    runApp(const _ConfigurationManquanteApp());
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
    // La session est chiffrée (Keystore Android) au lieu des SharedPreferences.
    authOptions: FlutterAuthClientOptions(localStorage: SecureLocalStorage()),
  );

  runApp(const ProviderScope(child: ClassCheckApp()));
}

class ClassCheckApp extends ConsumerWidget {
  const ClassCheckApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'ClassCheck',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.clair(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Affiché si l'application est lancée sans `--dart-define-from-file=dart_defines.json`.
class _ConfigurationManquanteApp extends StatelessWidget {
  const _ConfigurationManquanteApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.clair(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Configuration Supabase manquante.\n\n'
              'Lancez l\'application avec :\n'
              'flutter run --dart-define-from-file=dart_defines.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
