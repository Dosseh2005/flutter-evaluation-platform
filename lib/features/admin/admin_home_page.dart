import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Description de chaque section, affichée sur l'accueil.
const _descriptions = {
  SectionAdmin.questions:
      'Ajouter, modifier ou supprimer les questions de chaque discipline, '
      'ou remplacer une discipline entière par un fichier JSON.',
  SectionAdmin.tableauDeBord:
      'Consulter les derniers résultats, rechercher un candidat et filtrer '
      'par année scolaire.',
  SectionAdmin.statistiques:
      'Voir les taux de réussite par discipline et pour tous les étudiants, '
      'année par année.',
};

/// Accueil de l'administrateur (US4) : accès à la gestion des questions
/// (US5), au tableau de bord (US6) et aux statistiques (US7).
///
/// Seul un admin peut voir cette page : le router renvoie les candidats
/// vers /tests, et la base (RLS) refuse de toute façon leurs actions admin.
class AdminHomePage extends StatelessWidget {
  /// Crée l'accueil administrateur.
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminScaffold(
      titre: 'Administration',
      section: SectionAdmin.accueil,
      corps: ContenuCentre(
        child: ListView(
          padding: margesPage(context),
          children: [
            const EnTete(
              titre: 'Que voulez-vous faire ?',
              description:
                  'Gérez les évaluations et suivez les résultats '
                  'des candidats.',
            ),
            Panneau(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final s in _descriptions.keys) ...[
                    if (s != _descriptions.keys.first) const Divider(),
                    InkWell(
                      onTap: () => context.go(s.route),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 22,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Couleurs.selection,
                                borderRadius: BorderRadius.circular(rayonPetit),
                              ),
                              child: Icon(s.icone, color: Couleurs.encre),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.libelle,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _descriptions[s]!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Couleurs.texteSecondaire,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.chevron_right,
                              color: Couleurs.texteSecondaire,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
