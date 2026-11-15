import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/page_a_venir.dart';
import '../../core/router.dart';

/// Écran de connexion (candidat et admin). Sera codé dans l'US1 / US4.
class LoginPage extends StatelessWidget {
  /// Crée l'écran de connexion.
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageAVenir(
      titre: 'Connexion',
      us: 'US1 / US4 – Connexion',
      deconnexion: false,
      actions: [
        OutlinedButton(
          onPressed: () => context.go(Routes.register),
          child: const Text('Créer un compte'),
        ),
      ],
    );
  }
}
