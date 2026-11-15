import 'package:evaluation_app/features/candidat/profil_page.dart';
import 'package:evaluation_app/features/candidat/profil_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FauxProfil implements ProfilRepository {
  ({String adresse, String motivation})? misAJour;

  @override
  Future<Profil> monProfil() async => const Profil(
        nom: 'Dupont',
        prenom: 'Marie',
        email: 'marie@exemple.fr',
        age: 22,
        adresse: '1 rue de Paris',
        motivation: 'Reconversion',
      );

  @override
  Future<List<ScoreTest>> mesScores() async => [
        ScoreTest(
            discipline: 'Java', score: 4, total: 5, date: DateTime(2026, 11, 10)),
        ScoreTest(
            discipline: 'HTML/CSS',
            score: 1,
            total: 5,
            date: DateTime(2026, 10, 2)),
      ];

  @override
  Future<void> mettreAJour({
    required String adresse,
    required String motivation,
  }) async =>
      misAJour = (adresse: adresse, motivation: motivation);
}

void main() {
  Future<FauxProfil> ouvrir(WidgetTester tester) async {
    final faux = FauxProfil();
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [profilRepositoryProvider.overrideWithValue(faux)],
      child: const MaterialApp(home: ProfilPage()),
    ));
    await tester.pumpAndSettle();
    return faux;
  }

  testWidgets('Le profil affiche les informations et les scores',
      (tester) async {
    await ouvrir(tester);
    expect(find.text('Dupont'), findsOneWidget);
    expect(find.text('22 ans'), findsOneWidget);
    expect(find.text('4 / 5'), findsOneWidget);
    expect(find.text('Passé le 10/11/2026'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
  });

  testWidgets('Seules adresse et motivation sont modifiables', (tester) async {
    await ouvrir(tester);
    // 1 seul champ texte (adresse) : nom, prénom, email, âge ne sont pas éditables
    expect(find.byType(TextFormField), findsOneWidget);
  });

  testWidgets('La motivation propose exactement les 3 choix', (tester) async {
    await ouvrir(tester);
    final menu = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>));
    expect(menu.items!.map((i) => i.value),
        ["Poursuite d'études", 'Réorientation', 'Reconversion']);
  });

  testWidgets('Modifier adresse et motivation', (tester) async {
    final faux = await ouvrir(tester);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Adresse postale *'),
        '5 avenue de Lyon');
    await tester.tap(find.text('Reconversion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réorientation').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(faux.misAJour,
        (adresse: '5 avenue de Lyon', motivation: 'Réorientation'));
    expect(find.text('Profil mis à jour'), findsOneWidget);
  });

  testWidgets('Adresse vide : refusée', (tester) async {
    final faux = await ouvrir(tester);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Adresse postale *'), '  ');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text("L'adresse est obligatoire"), findsOneWidget);
    expect(faux.misAJour, isNull);
  });
}
