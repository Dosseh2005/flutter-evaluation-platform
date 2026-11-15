import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/page_a_venir.dart';
import '../../core/router.dart';

/// Profil du candidat : informations, scores, modification de l'adresse
/// et de la motivation. Sera codé dans l'US3.
class ProfilPage extends StatelessWidget {
  /// Crée la page « Mon profil ».
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageAVenir(
      titre: 'Mon profil',
      us: 'US3 – Voir et modifier son profil',
      actions: [
        OutlinedButton(
          onPressed: () => context.go(Routes.tests),
          child: const Text('Mes tests'),
        ),
      ],
    );
  }
}
