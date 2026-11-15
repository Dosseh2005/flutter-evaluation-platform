import 'package:supabase_flutter/supabase_flutter.dart';

/// URL du projet Supabase, passée au lancement avec
/// `--dart-define-from-file=env.json` (jamais écrite dans le code).
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

/// Clé publique (anon / publishable) du projet Supabase.
/// Ne JAMAIS mettre la clé `service_role` ici.
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Vrai si les deux valeurs ci-dessus ont bien été fournies au lancement.
bool get supabaseEstConfigure =>
    supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

/// Connecte l'application au projet Supabase. À appeler une seule fois,
/// dans `main()`, avant `runApp`.
Future<void> initialiserSupabase() async {
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
}

/// Raccourci vers le client Supabase, utilisable partout dans l'appli.
SupabaseClient get supabase => Supabase.instance.client;
