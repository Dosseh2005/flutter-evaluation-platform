import 'package:flutter/material.dart';

import '../../core/page_a_venir.dart';

/// Passage du test d'une discipline, une question à la fois avec
/// chronomètre. Sera codé dans l'US2.
class TestPage extends StatelessWidget {
  /// Crée la page de test pour la discipline [disciplineId].
  const TestPage({super.key, required this.disciplineId});

  /// Identifiant de la discipline (table `disciplines`).
  final int disciplineId;

  @override
  Widget build(BuildContext context) {
    return PageAVenir(
      titre: 'Test n°$disciplineId',
      us: 'US2 – Passer un test (chronomètre)',
    );
  }
}
