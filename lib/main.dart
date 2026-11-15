import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';

/// Point d'entrée : connecte Supabase puis lance l'application.
///
/// Lancement : `flutter run -d chrome --dart-define-from-file=env.json`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!supabaseEstConfigure) {
    runApp(const ConfigManquanteApp());
    return;
  }

  await initialiserSupabase();
  runApp(const ProviderScope(child: EvaluationApp()));
}

/// Application principale : thème + navigation go_router.
class EvaluationApp extends ConsumerWidget {
  /// Crée l'application.
  const EvaluationApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: "Plateforme d'évaluation",
      debugShowCheckedModeBanner: false,
      theme: construireTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Écran affiché si l'appli est lancée sans `env.json` : explique quoi
/// faire au lieu de planter.
class ConfigManquanteApp extends StatelessWidget {
  /// Crée l'écran d'erreur de configuration.
  const ConfigManquanteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: construireTheme(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Configuration Supabase manquante.\n\n'
              '1. Copier env.example.json en env.json et le remplir.\n'
              '2. Lancer : flutter run -d chrome --dart-define-from-file=env.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
