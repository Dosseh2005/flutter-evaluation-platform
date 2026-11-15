import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

/// Résultat d'une inscription réussie.
enum ResultatInscription {
  /// Le compte est créé et le candidat est déjà connecté.
  connecte,

  /// Le compte est créé mais Supabase demande de confirmer l'email
  /// (option « Confirm email » activée dans le projet).
  confirmationEmail,
}

/// Erreur d'authentification avec un message clair en français,
/// prêt à être affiché à l'utilisateur.
class ErreurAuth implements Exception {
  /// Crée une erreur avec son [message].
  const ErreurAuth(this.message);

  /// Message à afficher.
  final String message;

  @override
  String toString() => message;
}

/// Inscription, connexion et déconnexion via Supabase Auth (US1, US4).
class AuthRepository {
  /// Crée le repository à partir du client [_auth] de Supabase.
  AuthRepository(this._auth);

  final GoTrueClient _auth;

  /// Crée le compte d'un candidat (US1).
  ///
  /// Les informations du profil sont envoyées dans `data` : le trigger SQL
  /// `handle_new_user` crée alors la ligne dans `profiles`. Si une
  /// contrainte échoue (doublon Nom + Email, champ manquant), le compte
  /// n'est PAS créé et une [ErreurAuth] est levée.
  Future<ResultatInscription> inscrire({
    required String nom,
    required String prenom,
    required String email,
    required String motDePasse,
    required int age,
    required String adresse,
    required String motivation,
  }) async {
    try {
      final reponse = await _auth.signUp(
        email: email.trim(),
        password: motDePasse,
        data: {
          'nom': nom.trim(),
          'prenom': prenom.trim(),
          'age': age,
          'adresse': adresse.trim(),
          'motivation': motivation,
        },
      );
      // Avec la protection anti-énumération de Supabase, un email déjà
      // utilisé peut renvoyer un « faux » utilisateur sans identité.
      if (reponse.user?.identities?.isEmpty ?? false) {
        throw const ErreurAuth('Un compte existe déjà avec cet email.');
      }
      return reponse.session != null
          ? ResultatInscription.connecte
          : ResultatInscription.confirmationEmail;
    } on AuthException catch (e) {
      throw ErreurAuth(traduireErreurAuth(e));
    }
  }

  /// Connecte un candidat ou l'administrateur (US1, US4). Le router
  /// redirige ensuite automatiquement selon le rôle.
  Future<void> connecter({
    required String email,
    required String motDePasse,
  }) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: motDePasse);
    } on AuthException catch (e) {
      throw ErreurAuth(traduireErreurAuth(e));
    }
  }

  /// Déconnecte l'utilisateur.
  Future<void> deconnecter() => _auth.signOut();
}

/// Transforme une erreur Supabase Auth en message clair en français.
String traduireErreurAuth(AuthException e) {
  switch (e.code) {
    case 'user_already_exists':
    case 'email_exists':
      return 'Un compte existe déjà avec cet email.';
    case 'invalid_credentials':
      return 'Email ou mot de passe incorrect.';
    case 'email_not_confirmed':
      return "Votre email n'est pas encore confirmé : vérifiez votre boîte mail.";
    case 'weak_password':
      return 'Mot de passe trop faible.';
    case 'email_address_invalid':
      return 'Email invalide.';
    case 'over_request_rate_limit':
    case 'over_email_send_rate_limit':
      return 'Trop de tentatives, réessayez dans quelques minutes.';
  }
  // Erreur levée par la base (trigger handle_new_user) : contrainte
  // unique (nom, email) ou champ obligatoire manquant.
  if (e.message.contains('Database error')) {
    return 'Inscription refusée : un compte existe déjà avec ce nom et cet '
        'email, ou une information est invalide.';
  }
  return 'Erreur : ${e.message}';
}

/// Fournit l'[AuthRepository] de l'application.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(supabase.auth),
);
