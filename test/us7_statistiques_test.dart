import 'package:evaluation_app/features/admin/statistiques/statistiques_page.dart';
import 'package:evaluation_app/features/admin/statistiques/stats_repository.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FauxStats implements StatsRepository {
  String? anneeDemandee;

  @override
  Future<List<StatDiscipline>> parDiscipline(String annee) async {
    anneeDemandee = annee;
    if (annee == '2025-2026') {
      return const [
        StatDiscipline(discipline: 'Java', nbTests: 0, nbReussis: 0),
        StatDiscipline(discipline: 'Algorithmes', nbTests: 0, nbReussis: 0),
        StatDiscipline(discipline: 'HTML/CSS', nbTests: 0, nbReussis: 0),
      ];
    }
    return const [
      StatDiscipline(discipline: 'Java', nbTests: 4, nbReussis: 3),
      StatDiscipline(discipline: 'Algorithmes', nbTests: 2, nbReussis: 1),
      StatDiscipline(discipline: 'HTML/CSS', nbTests: 4, nbReussis: 0),
    ];
  }

  @override
  Future<List<String>> annees() async => ['2025-2026'];
}

void main() {
  group('Calcul des taux', () {
    test('Taux de réussite d\'une discipline', () {
      const s = StatDiscipline(discipline: 'Java', nbTests: 4, nbReussis: 3);
      expect(s.tauxReussite, 75);
      expect(s.nbEchoues, 1);
    });

    test('Aucun test : 0 % (pas de division par zéro)', () {
      const s = StatDiscipline(discipline: 'Java', nbTests: 0, nbReussis: 0);
      expect(s.tauxReussite, 0);
    });

    test('Camembert général = somme de toutes les disciplines', () {
      final g = statGenerale(const [
        StatDiscipline(discipline: 'Java', nbTests: 4, nbReussis: 3),
        StatDiscipline(discipline: 'Algorithmes', nbTests: 2, nbReussis: 1),
        StatDiscipline(discipline: 'HTML/CSS', nbTests: 4, nbReussis: 0),
      ]);
      expect(g.nbTests, 10);
      expect(g.nbReussis, 4);
      expect(g.tauxReussite, 40);
    });
  });

  testWidgets('Un camembert par discipline + un général, filtre par année',
      (tester) async {
    final faux = FauxStats();
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [statsRepositoryProvider.overrideWithValue(faux)],
      child: const MaterialApp(home: StatistiquesPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Tous les étudiants'), findsOneWidget);
    expect(find.text('Java'), findsOneWidget);
    expect(find.text('Algorithmes'), findsOneWidget);
    expect(find.text('HTML/CSS'), findsOneWidget);
    expect(find.byType(PieChart), findsNWidgets(4));
    expect(find.text('4 réussi(s), 6 échoué(s)'), findsOneWidget);

    // Changer d'année : plus aucun test → pas de camembert
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025-2026').last);
    await tester.pumpAndSettle();
    expect(faux.anneeDemandee, '2025-2026');
    expect(find.byType(PieChart), findsNothing);
    expect(find.text('Aucun test cette année'), findsNWidgets(4));
  });
}
