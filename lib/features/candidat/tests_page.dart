import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/page_a_venir.dart';
import '../../core/router.dart';

/// Liste des tests du candidat (Java, Algorithmes, HTML/CSS). Sera codée
/// dans l'US2.
class TestsPage extends StatelessWidget {
  /// Crée la page « Mes tests ».
  const TestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageAVenir(
      titre: 'Mes tests',
      us: 'US2 – Passer un test',
      actions: [
        OutlinedButton(
          onPressed: () => context.go(Routes.profil),
          child: const Text('Mon profil'),
        ),
      ],
    );
  }
}
