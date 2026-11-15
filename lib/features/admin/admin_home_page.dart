import 'package:flutter/material.dart';

import '../../core/page_a_venir.dart';

/// Accueil de l'administrateur : menu Questions / Tableau de bord /
/// Statistiques. Sera codé dans l'US4, puis US5, US6 et US7.
class AdminHomePage extends StatelessWidget {
  /// Crée l'accueil administrateur.
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageAVenir(
      titre: 'Administration',
      us: 'US4 – Accueil admin (puis US5, US6, US7)',
    );
  }
}
