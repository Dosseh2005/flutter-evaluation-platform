import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/session.dart';

/// Une entrée du menu administrateur.
class _EntreeMenu {
  const _EntreeMenu(this.titre, this.description, this.icone, this.route);

  final String titre;
  final String description;
  final IconData icone;
  final String route;
}

const _menu = [
  _EntreeMenu(
    'Questions',
    'Ajouter, modifier, supprimer ou importer (JSON) les questions de chaque discipline',
    Icons.quiz_outlined,
    Routes.adminQuestions,
  ),
  _EntreeMenu(
    'Tableau de bord',
    'Résultats récents des candidats, recherche et filtre par année scolaire',
    Icons.table_chart_outlined,
    Routes.adminTableauDeBord,
  ),
  _EntreeMenu(
    'Statistiques',
    'Taux de réussite par discipline et par année (camemberts)',
    Icons.pie_chart_outline,
    Routes.adminStatistiques,
  ),
];

/// Accueil de l'administrateur (US4) : menu vers la gestion des questions
/// (US5), le tableau de bord (US6) et les statistiques (US7), plus un
/// bouton de déconnexion.
///
/// Seul un admin peut voir cette page : le router renvoie les candidats
/// vers /tests, et la base (RLS) refuse de toute façon leurs actions admin.
class AdminHomePage extends ConsumerWidget {
  /// Crée l'accueil administrateur.
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider).deconnecter(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Que voulez-vous faire ?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                for (final entree in _menu)
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Icon(entree.icone, size: 32),
                      title: Text(entree.titre),
                      subtitle: Text(entree.description),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(entree.route),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
