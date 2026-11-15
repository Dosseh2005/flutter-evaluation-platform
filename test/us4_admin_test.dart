import 'package:evaluation_app/core/router.dart';
import 'package:evaluation_app/core/session.dart';
import 'package:evaluation_app/features/admin/admin_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets("L'accueil admin affiche le menu et ouvre chaque section",
      (tester) async {
    final router = GoRouter(
      initialLocation: Routes.admin,
      routes: [
        GoRoute(path: Routes.admin, builder: (_, _) => const AdminHomePage()),
        for (final r in [
          Routes.adminQuestions,
          Routes.adminTableauDeBord,
          Routes.adminStatistiques,
        ])
          GoRoute(
            path: r,
            builder: (_, _) => AdminPageAVenir(titre: r, us: 'test'),
          ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    ));

    expect(find.text('Questions'), findsOneWidget);
    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.text('Statistiques'), findsOneWidget);
    expect(find.byTooltip('Se déconnecter'), findsOneWidget);

    await tester.tap(find.text('Questions'));
    await tester.pumpAndSettle();
    expect(find.text(Routes.adminQuestions), findsOneWidget);

    await tester.tap(find.text('Retour au menu'));
    await tester.pumpAndSettle();
    expect(find.text('Que voulez-vous faire ?'), findsOneWidget);
  });

  test('Un candidat ne peut ouvrir aucune page /admin/...', () {
    for (final chemin in [
      Routes.admin,
      Routes.adminQuestions,
      Routes.adminTableauDeBord,
      Routes.adminStatistiques,
    ]) {
      expect(
        calculerRedirection(
          chemin: chemin,
          chargement: false,
          estConnecte: true,
          role: Role.candidat,
        ),
        Routes.tests,
      );
    }
  });
}
