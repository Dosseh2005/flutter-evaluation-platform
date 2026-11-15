import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/page_a_venir.dart';
import '../../core/router.dart';

/// Écran d'inscription d'un candidat. Sera codé dans l'US1.
class RegisterPage extends StatelessWidget {
  /// Crée l'écran d'inscription.
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageAVenir(
      titre: 'Inscription',
      us: 'US1 – Inscription des candidats',
      deconnexion: false,
      actions: [
        OutlinedButton(
          onPressed: () => context.go(Routes.login),
          child: const Text("J'ai déjà un compte"),
        ),
      ],
    );
  }
}
