import 'package:evaluation_app/features/candidat/tests_page.dart';
import 'package:evaluation_app/features/test/test_page.dart';
import 'package:evaluation_app/features/test/test_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Faux serveur : 2 questions, enregistre les réponses reçues.
class FauxTest implements TestRepository {
  FauxTest({this.dejaTermine = false, this.commence = true});

  final bool dejaTermine;

  /// Vrai si le candidat a déjà cliqué « Commencer » (tentative créée).
  final bool commence;
  final reponses = <int, List<int>>{};
  int demarrages = 0;

  final _questions = [
    const QuestionTest(
      id: 10,
      enonce: 'Mot-clé pour hériter ?',
      plusieursReponses: false,
      numero: 1,
      total: 2,
      tempsRestantSec: 30,
      choix: [(id: 1, texte: 'extends'), (id: 2, texte: 'implements')],
    ),
    const QuestionTest(
      id: 11,
      enonce: 'Types primitifs ?',
      plusieursReponses: true,
      numero: 2,
      total: 2,
      tempsRestantSec: 5,
      choix: [(id: 3, texte: 'int'), (id: 4, texte: 'String')],
    ),
  ];

  @override
  Future<List<TestDisponible>> mesTests() async => [
        TestDisponible(
          disciplineId: 1,
          discipline: 'Java',
          nbQuestions: 2,
          tentativeId: dejaTermine || commence ? 99 : null,
          score: dejaTermine ? 1 : null,
          total: dejaTermine ? 2 : null,
          termine: dejaTermine,
        ),
      ];

  @override
  Future<int> commencer(int disciplineId) async {
    demarrages++;
    return 99;
  }

  @override
  Future<QuestionTest?> questionSuivante(int tentativeId) async {
    for (final q in _questions) {
      if (!reponses.containsKey(q.id)) return q;
    }
    return null;
  }

  @override
  Future<void> repondre(int tentativeId, int questionId, List<int> choixIds) async {
    reponses[questionId] = choixIds;
  }

  @override
  Future<({int score, int total})> resultat(int tentativeId) async =>
      (score: reponses[10]?.contains(1) == true ? 1 : 0, total: 2);
}

class FauxListe implements TestRepository {
  @override
  Future<List<TestDisponible>> mesTests() async => const [
        TestDisponible(
            disciplineId: 1,
            discipline: 'Java',
            nbQuestions: 5,
            tentativeId: 7,
            score: 4,
            total: 5,
            termine: true),
        TestDisponible(
            disciplineId: 2,
            discipline: 'Algorithmes',
            nbQuestions: 5,
            tentativeId: 8),
        TestDisponible(disciplineId: 3, discipline: 'HTML/CSS', nbQuestions: 0),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> ouvrir(WidgetTester tester, TestRepository repo, Widget page) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [testRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(home: page),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('Seuil de réussite : 50 %', () {
    expect(estReussi(5, 10), isTrue);
    expect(estReussi(4, 10), isFalse);
    expect(estReussi(0, 0), isFalse);
  });

  testWidgets('Mes tests : score si déjà passé, Reprendre, indisponible',
      (tester) async {
    await ouvrir(tester, FauxListe(), const TestsPage());

    expect(find.text('Déjà passé – score 4/5'), findsOneWidget);
    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.text('Pas encore disponible'), findsOneWidget);
    // Les boutons « Commencer » du test passé et du test vide sont désactivés
    final boutons = tester
        .widgetList<FilledButton>(find.widgetWithText(FilledButton, 'Commencer'));
    expect(boutons.every((b) => b.onPressed == null), isTrue);
  });

  testWidgets('Passer un test : réponse, chrono automatique, score',
      (tester) async {
    final repo = FauxTest();
    await ouvrir(tester, repo, const TestPage(disciplineId: 1));

    // Question 1 (radio) : Valider désactivé tant que rien n'est coché
    expect(find.text('Question 1/2'), findsOneWidget);
    expect(find.text('30 s'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Valider')).onPressed,
      isNull,
    );
    await tester.tap(find.text('implements'));
    await tester.tap(find.text('extends')); // radio : remplace le choix
    await tester.pump();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(repo.reponses[10], [1]);
    // L'écran du test ne démarre jamais lui-même un test
    expect(repo.demarrages, 0);

    // Question 2 (checkbox, 5 s) : on ne répond pas, le chrono envoie seul
    expect(find.text('Question 2/2'), findsOneWidget);
    await tester.tap(find.text('int'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('2 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(repo.reponses[11], [3]);

    // Résultat
    expect(find.textContaining('Votre score : 1 / 2 (50 %)'), findsOneWidget);
    expect(find.textContaining('Test réussi'), findsOneWidget);
  });

  testWidgets('Test déjà passé : score affiché, pas de nouveau départ',
      (tester) async {
    final repo = FauxTest(dejaTermine: true);
    await ouvrir(tester, repo, const TestPage(disciplineId: 1));
    expect(repo.demarrages, 0);
    expect(find.textContaining('Votre score'), findsOneWidget);
  });

  testWidgets(
      'Arriver sur la page d\'un test non commencé ne le démarre PAS '
      '(retour arrière, adresse tapée…)', (tester) async {
    final repo = FauxTest(commence: false);
    await ouvrir(tester, repo, const TestPage(disciplineId: 1));
    expect(repo.demarrages, 0);
    expect(find.textContaining("pas encore été commencé"), findsOneWidget);
  });

  testWidgets('« Commencer » + confirmation démarre le test puis l\'ouvre',
      (tester) async {
    final repo = FauxTest(commence: false);
    final router = GoRouter(
      initialLocation: '/tests',
      routes: [
        GoRoute(path: '/tests', builder: (_, _) => const TestsPage()),
        GoRoute(
          path: '/test/:id',
          builder: (_, s) =>
              TestPage(disciplineId: int.parse(s.pathParameters['id']!)),
        ),
      ],
    );
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [testRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    // Annuler : rien n'est démarré
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(repo.demarrages, 0);

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Commencer').last);
    await tester.pump();
    expect(repo.demarrages, 1);
  });
}
