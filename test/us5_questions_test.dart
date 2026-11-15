import 'dart:convert';
import 'dart:io';

import 'package:evaluation_app/core/disciplines.dart';
import 'package:evaluation_app/features/admin/questions/question.dart';
import 'package:evaluation_app/features/admin/questions/questions_page.dart';
import 'package:evaluation_app/features/admin/questions/questions_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Question q({
  String enonce = 'Question ?',
  TypeQuestion type = TypeQuestion.radio,
  int temps = 30,
  List<Choix>? choix,
}) =>
    Question(
      enonce: enonce,
      type: type,
      tempsLimiteSec: temps,
      choix: choix ??
          const [
            Choix(texte: 'A', correct: true),
            Choix(texte: 'B', correct: false),
          ],
    );

class FauxDisciplines implements DisciplinesRepository {
  @override
  Future<List<Discipline>> lister() async =>
      const [Discipline(id: 1, nom: 'Java'), Discipline(id: 2, nom: 'Algorithmes')];
}

class FauxQuestions implements QuestionsRepository {
  final Map<int, List<Question>> base = {
    1: [q(enonce: 'Question Java 1')],
    2: [],
  };
  int? supprimee;
  List<Question>? importees;

  @override
  Future<List<Question>> lister(int disciplineId) async => base[disciplineId]!;

  @override
  Future<void> enregistrer(int disciplineId, Question question) async =>
      base[disciplineId]!.add(question);

  @override
  Future<void> supprimer(int questionId) async => supprimee = questionId;

  @override
  Future<int> reinitialiser(int disciplineId, List<Question> questions) async {
    importees = questions;
    base[disciplineId] = questions;
    return questions.length;
  }
}

void main() {
  group('Contrôles d\'une question (verifierQuestion)', () {
    test('Question correcte', () => expect(verifierQuestion(q()), isEmpty));

    test('Énoncé vide', () {
      expect(verifierQuestion(q(enonce: '  ')), contains("L'énoncé est vide"));
    });

    test('Temps limite à 0', () {
      expect(verifierQuestion(q(temps: 0)), isNotEmpty);
    });

    test('Moins de 2 choix', () {
      expect(
        verifierQuestion(q(choix: const [Choix(texte: 'A', correct: true)])),
        contains('Il faut au moins 2 choix'),
      );
    });

    test('Aucune bonne réponse', () {
      expect(
        verifierQuestion(q(choix: const [
          Choix(texte: 'A', correct: false),
          Choix(texte: 'B', correct: false),
        ])),
        contains('Il faut au moins une bonne réponse'),
      );
    });

    test('Radio avec 2 bonnes réponses : refusé ; Checkbox : accepté', () {
      const deuxBonnes = [
        Choix(texte: 'A', correct: true),
        Choix(texte: 'B', correct: true),
      ];
      expect(verifierQuestion(q(choix: deuxBonnes)), isNotEmpty);
      expect(
        verifierQuestion(q(type: TypeQuestion.checkbox, choix: deuxBonnes)),
        isEmpty,
      );
    });
  });

  group('Fichiers d\'import JSON', () {
    for (final fichier in [
      'data/questions_java.json',
      'data/questions_algorithmes.json',
      'data/questions_html_css.json',
    ]) {
      test('$fichier est valide', () {
        final questions =
            lireFichierImport(jsonDecode(File(fichier).readAsStringSync()));
        expect(questions, hasLength(5));
      });
    }

    test('Fichier sans liste « questions » : refusé', () {
      expect(() => lireFichierImport({'autre': 1}), throwsFormatException);
    });

    test('Type inconnu : refusé avec le numéro de la question', () {
      expect(
        () => lireFichierImport({
          'questions': [
            {
              'enonce': 'X',
              'type': 'texte',
              'temps_limite_sec': 10,
              'choix': [],
            },
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('Radio avec deux bonnes réponses : refusé', () {
      expect(
        () => lireFichierImport({
          'questions': [
            {
              'enonce': 'X',
              'type': 'radio',
              'temps_limite_sec': 10,
              'choix': [
                {'texte': 'A', 'correct': true},
                {'texte': 'B', 'correct': true},
              ],
            },
          ],
        }),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('question 1'))),
      );
    });

    test('Le JSON envoyé au serveur garde le même format', () {
      expect(q().toJson(), {
        'enonce': 'Question ?',
        'type': 'radio',
        'temps_limite_sec': 30,
        'choix': [
          {'texte': 'A', 'correct': true},
          {'texte': 'B', 'correct': false},
        ],
      });
    });
  });

  group('Écran Questions', () {
    Future<FauxQuestions> ouvrir(WidgetTester tester, {String? fichier}) async {
      final faux = FauxQuestions();
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          disciplinesRepositoryProvider.overrideWithValue(FauxDisciplines()),
          questionsRepositoryProvider.overrideWithValue(faux),
          choisirFichierJsonProvider.overrideWithValue(() async => fichier),
        ],
        child: const MaterialApp(home: QuestionsPage()),
      ));
      await tester.pumpAndSettle();
      return faux;
    }

    testWidgets('Un onglet par discipline et les questions affichées',
        (tester) async {
      await ouvrir(tester);
      expect(find.text('Java'), findsOneWidget);
      expect(find.text('Algorithmes'), findsOneWidget);
      expect(find.text('1. Question Java 1'), findsOneWidget);
    });

    testWidgets('Ajouter une question via le formulaire', (tester) async {
      final faux = await ouvrir(tester);
      await tester.tap(find.text('Ajouter une question'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Énoncé *'), 'Nouvelle ?');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Choix 1'), 'Oui');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Choix 2'), 'Non');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(faux.base[1]!.last.enonce, 'Nouvelle ?');
      expect(faux.base[1]!.last.nbBonnes, 1);
      expect(find.text('2. Nouvelle ?'), findsOneWidget);
    });

    testWidgets('Supprimer demande une confirmation', (tester) async {
      final faux = FauxQuestions();
      faux.base[1] = [
        Question(
          id: 42,
          enonce: 'À supprimer',
          type: TypeQuestion.radio,
          tempsLimiteSec: 10,
          choix: q().choix,
        ),
      ];
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          disciplinesRepositoryProvider.overrideWithValue(FauxDisciplines()),
          questionsRepositoryProvider.overrideWithValue(faux),
        ],
        child: const MaterialApp(home: QuestionsPage()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Supprimer'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer la question ?'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(faux.supprimee, isNull);

      await tester.tap(find.byTooltip('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();
      expect(faux.supprimee, 42);
    });

    testWidgets('Import JSON : confirmation puis remplacement',
        (tester) async {
      final faux = await ouvrir(tester,
          fichier: File('data/questions_java.json').readAsStringSync());
      await tester.tap(find.text('Réinitialiser via JSON'));
      await tester.pumpAndSettle();
      expect(find.textContaining('remplacées par les 5 questions'),
          findsOneWidget);

      await tester.tap(find.text('Remplacer'));
      await tester.pumpAndSettle();
      expect(faux.importees, hasLength(5));
      expect(find.text('5 questions importées'), findsOneWidget);
    });

    testWidgets('Import d\'un fichier invalide : message, rien modifié',
        (tester) async {
      final faux = await ouvrir(tester, fichier: '{"questions": []}');
      await tester.tap(find.text('Réinitialiser via JSON'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Fichier invalide'), findsOneWidget);
      expect(faux.importees, isNull);
    });
  });
}
