import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
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
    if (ok == true && mounted) context.go(Routes.test(test.disciplineId));
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
            largeurMax: 700,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Choisissez une discipline. Chaque test ne peut être passé '
                  "qu'une seule fois.",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                for (final test in tests)
                  _CarteTest(
                    test: test,
                    commencer: () => _commencer(test),
                    reprendre: () =>
                        context.go(Routes.test(test.disciplineId)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CarteTest extends StatelessWidget {
  const _CarteTest({
    required this.test,
    required this.commencer,
    required this.reprendre,
  });

  final TestDisponible test;
  final VoidCallback commencer;
  final VoidCallback reprendre;

  @override
  Widget build(BuildContext context) {
    final String sousTitre;
    final Widget bouton;
    if (test.termine) {
      sousTitre = 'Déjà passé – score ${test.score}/${test.total}';
      bouton = const FilledButton(onPressed: null, child: Text('Commencer'));
    } else if (test.enCours) {
      sousTitre = 'Test commencé, pas encore terminé';
      bouton = FilledButton.tonal(
        onPressed: reprendre,
        child: const Text('Reprendre'),
      );
    } else if (test.nbQuestions == 0) {
      sousTitre = 'Pas encore disponible';
      bouton = const FilledButton(onPressed: null, child: Text('Commencer'));
    } else {
      sousTitre = '${test.nbQuestions} questions chronométrées';
      bouton = FilledButton(onPressed: commencer, child: const Text('Commencer'));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              test.termine ? Icons.check_circle : Icons.quiz_outlined,
              size: 36,
              color: test.termine ? Colors.green : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(test.discipline,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(sousTitre),
                ],
              ),
            ),
            const SizedBox(width: 8),
            bouton,
          ],
        ),
      ),
    );
  }
}
