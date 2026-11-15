import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/erreurs.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../test/test_repository.dart';

/// « Mes tests » (US2) : les 3 disciplines avec, pour chacune, un bouton
/// « Commencer », « Reprendre » ou le score si le test est déjà passé.
class TestsPage extends ConsumerStatefulWidget {
  /// Crée la page.
  const TestsPage({super.key});

  @override
  ConsumerState<TestsPage> createState() => _TestsPageState();
}

class _TestsPageState extends ConsumerState<TestsPage> {
  late Future<List<TestDisponible>> _tests;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _charger() => _tests = ref.read(testRepositoryProvider).mesTests();

  Future<void> _commencer(TestDisponible test) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Commencer le test ${test.discipline} ?'),
        content: Text(
          '• ${test.nbQuestions} questions, une à la fois.\n'
          '• Chaque question a un temps limite : à la fin du temps, votre '
          'réponse est envoyée automatiquement.\n'
          '• Vous ne pourrez passer ce test qu\'une seule fois.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Commencer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Le test est démarré ICI, seulement après la confirmation.
    final messenger = ScaffoldMessenger.of(context);
    final routeur = GoRouter.of(context);
    try {
      await ref.read(testRepositoryProvider).commencer(test.disciplineId);
      routeur.go(Routes.test(test.disciplineId));
    } catch (e) {
      afficherMessage(messenger, messageErreur(e), erreur: true);
      if (mounted) setState(_charger);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CandidatScaffold(
      titre: 'Mes tests',
      corps: ChargementFuture<List<TestDisponible>>(
        future: _tests,
        reessayer: () => setState(_charger),
        builder: (context, tests) => RefreshIndicator(
          onRefresh: () async {
            setState(_charger);
            await _tests;
          },
          child: ContenuCentre(
            largeurMax: 820,
            child: ListView(
              padding: margesPage(context),
              children: [
                const EnTete(
                  titre: 'Mes tests',
                  description:
                      'Choisissez une discipline. Chaque test ne '
                      "peut être passé qu'une seule fois.",
                ),
                Panneau(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < tests.length; i++) ...[
                        if (i > 0) const Divider(),
                        _LigneTest(
                          test: tests[i],
                          commencer: () => _commencer(tests[i]),
                          reprendre: () =>
                              context.go(Routes.test(tests[i].disciplineId)),
                        ),
                      ],
                    ],
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

/// Une discipline dans la liste : nom, état, et l'action possible.
class _LigneTest extends StatelessWidget {
  const _LigneTest({
    required this.test,
    required this.commencer,
    required this.reprendre,
  });

  final TestDisponible test;
  final VoidCallback commencer;
  final VoidCallback reprendre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String sousTitre;
    final Widget bouton;
    Pastille? statut;
    if (test.termine) {
      final reussi = estReussi(test.score ?? 0, test.total ?? 0);
      sousTitre = 'Déjà passé – score ${test.score}/${test.total}';
      statut = Pastille(
        reussi ? 'Réussi' : 'Non réussi',
        ton: reussi ? TonPastille.reussite : TonPastille.alerte,
      );
      bouton = const FilledButton(onPressed: null, child: Text('Commencer'));
    } else if (test.enCours) {
      sousTitre = 'Test commencé, pas encore terminé';
      statut = const Pastille('En cours');
      bouton = FilledButton(
        onPressed: reprendre,
        child: const Text('Reprendre'),
      );
    } else if (test.nbQuestions == 0) {
      sousTitre = 'Pas encore disponible';
      bouton = const FilledButton(onPressed: null, child: Text('Commencer'));
    } else {
      sousTitre = '${test.nbQuestions} questions chronométrées';
      bouton = FilledButton(
        onPressed: commencer,
        child: const Text('Commencer'),
      );
    }

    final infos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(test.discipline, style: theme.textTheme.titleLarge),
            ?statut,
          ],
        ),
        const SizedBox(height: 4),
        Text(
          sousTitre,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Couleurs.texteSecondaire,
          ),
        ),
      ],
    );

    // Sur téléphone, le bouton passe sous le texte, en pleine largeur
    // (plus facile à toucher avec le pouce).
    final telephone = MediaQuery.sizeOf(context).width < 520;
    return Semantics(
      container: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: telephone ? 18 : 24,
          vertical: telephone ? 18 : 20,
        ),
        child: telephone
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [infos, const SizedBox(height: 14), bouton],
              )
            : Row(
                children: [
                  Expanded(child: infos),
                  const SizedBox(width: 16),
                  bouton,
                ],
              ),
      ),
    );
  }
}
