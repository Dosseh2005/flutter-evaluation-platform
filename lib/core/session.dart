import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Rôle d'un utilisateur, lu dans la colonne `profiles.role`.
enum Role {
  /// Candidat : passe les tests et consulte son profil.
  candidat,

  /// Administrateur : gère les questions et consulte les résultats.
  admin,
}

/// Suit l'utilisateur connecté et son rôle.
///
/// Le router l'écoute (`refreshListenable`) : à chaque connexion ou
/// déconnexion, il recalcule la page à afficher.
class Session extends ChangeNotifier {
  /// Commence à écouter les connexions / déconnexions Supabase.
  Session() {
    _abonnement = supabase.auth.onAuthStateChange.listen((_) => _charger());
    _charger();
  }

  late final StreamSubscription<AuthState> _abonnement;

  /// Vrai tant que le rôle de l'utilisateur est en cours de lecture.
  bool chargement = true;

  /// Rôle de l'utilisateur connecté, ou `null` s'il n'est pas connecté.
  Role? role;

  /// Vrai si quelqu'un est connecté.
  bool get estConnecte => supabase.auth.currentUser != null;

  /// Lit le rôle de l'utilisateur connecté dans la table `profiles`.
  Future<void> _charger() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      role = null;
      chargement = false;
      notifyListeners();
      return;
    }
    chargement = true;
    notifyListeners();
    try {
      final ligne = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      role = ligne?['role'] == 'admin' ? Role.admin : Role.candidat;
    } catch (_) {
      // En cas d'erreur réseau, on considère l'utilisateur comme candidat :
      // de toute façon la base (RLS) refuse les actions admin.
      role = Role.candidat;
    }
    chargement = false;
    notifyListeners();
  }

  /// Déconnecte l'utilisateur ; le router le renvoie vers /login.
  Future<void> deconnecter() => supabase.auth.signOut();

  @override
  void dispose() {
    _abonnement.cancel();
    super.dispose();
  }
}

/// Fournit la [Session] unique de l'application.
final sessionProvider = Provider<Session>((ref) {
  final session = Session();
  ref.onDispose(session.dispose);
  return session;
});
