import 'package:evaluation_app/core/annee_scolaire.dart';
import 'package:evaluation_app/features/admin/tableau_de_bord/resultats_repository.dart';
import 'package:evaluation_app/features/admin/tableau_de_bord/tableau_de_bord_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faux serveur qui applique la recherche et le filtre comme la base.
class FauxResultats implements ResultatsRepository {
  final donnees = [
    Resultat(
        nom: 'Dupont',
        prenom: 'Marie',
        discipline: 'Java',
        score: 4,
        total: 5,
        date: DateTime(2026, 11, 10),
        anneeScolaire: '2026-2027'),
    Resultat(
        nom: 'Martin',
        prenom: 'Lucas',
        discipline: 'HTML/CSS',
        score: 1,
        total: 5,
        date: DateTime(2026, 3, 2),
        anneeScolaire: '2025-2026'),
  ];

  @override
  Future<List<Resultat>> derniersResultats({
    String recherche = '',
    String? annee,
  }) async {
    final t = recherche.toLowerCase();
    return donnees
        .where((r) => annee == null || r.anneeScolaire == annee)
        .where((r) =>
            r.nom.toLowerCase().contains(t) ||
            r.prenom.toLowerCase().contains(t))
        .toList();
  }

  @override
  Future<List<String>> annees() async => ['2025-2026', '2026-2027'];
}

void main() {
  group('Année scolaire (septembre à août)', () {
    test('Novembre 2026 → 2026-2027', () {
      expect(anneeScolaire(DateTime(2026, 11, 15)), '2026-2027');
    });
    test('Mars 2027 → 2026-2027', () {
      expect(anneeScolaire(DateTime(2027, 3, 1)), '2026-2027');
    });
    test('1er septembre : nouvelle année', () {
      expect(anneeScolaire(DateTime(2027, 9, 1)), '2027-2028');
      expect(anneeScolaire(DateTime(2027, 8, 31)), '2026-2027');
    });
    test('Liste des années : récentes d\'abord, année en cours incluse', () {
      expect(
        anneesAProposer(['2024-2025', '2025-2026', '2024-2025'],
            maintenant: DateTime(2026, 11, 15)),
        ['2026-2027', '2025-2026', '2024-2025'],
      );
    });
  });

  test('La recherche enlève les caractères spéciaux des filtres', () {
    expect(nettoyerRecherche(' Du,pont() '), 'Du pont');
    expect(nettoyerRecherche('marie'), 'marie');
  });

  group('Écran Tableau de bord', () {
    Future<void> ouvrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          resultatsRepositoryProvider.overrideWithValue(FauxResultats()),
        ],
        child: const MaterialApp(home: TableauDeBordPage()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('Affiche les derniers résultats', (tester) async {
      await ouvrir(tester);
      expect(find.text('Dupont'), findsOneWidget);
      expect(find.text('Martin'), findsOneWidget);
      expect(find.text('4/5'), findsOneWidget);
      expect(find.text('Réussi'), findsOneWidget);
      expect(find.text('Échoué'), findsOneWidget);
    });

    testWidgets('Recherche par prénom (sans majuscule)', (tester) async {
      await ouvrir(tester);
      await tester.enterText(find.byType(TextField), 'lucas');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Martin'), findsOneWidget);
      expect(find.text('Dupont'), findsNothing);
    });

    testWidgets('Filtre par année scolaire', (tester) async {
      await ouvrir(tester);
      await tester.tap(find.text('Toutes les années'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2025-2026').last);
      await tester.pumpAndSettle();
      expect(find.text('Martin'), findsOneWidget);
      expect(find.text('Dupont'), findsNothing);
    });
  });
}
