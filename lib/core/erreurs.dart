import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/auth_repository.dart';

/// Transforme n'importe quelle erreur (base de données, réseau, connexion)
/// en message clair en français, prêt à afficher à l'utilisateur.
///
/// Les erreurs levées par nos fonctions SQL (`raise exception '...'`) sont
/// déjà en français : on affiche leur message tel quel.
String messageErreur(Object erreur) {
  if (erreur is ErreurAuth) return erreur.message;
  if (erreur is AuthException) return traduireErreurAuth(erreur);
  if (erreur is PostgrestException) {
    switch (erreur.code) {
      case '42501':
        return "Action non autorisée : vous n'avez pas les droits nécessaires.";
      case '23505':
        return 'Cette donnée existe déjà.';
      case 'PGRST202':
      case 'PGRST205':
        return 'La base de données n\'est pas à jour : exécutez '
            'supabase/migration_002.sql dans Supabase.';
    }
    return erreur.message;
  }
  final texte = erreur.toString();
  if (texte.contains('ClientException') ||
      texte.contains('SocketException') ||
      texte.contains('Failed to fetch')) {
    return 'Impossible de joindre le serveur. Vérifiez votre connexion '
        'Internet puis réessayez.';
  }
  if (erreur is FormatException) return 'Format invalide : ${erreur.message}';
  return 'Erreur inattendue : $texte';
}
