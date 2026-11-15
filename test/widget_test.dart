import 'package:evaluation_app/core/router.dart';
import 'package:evaluation_app/core/session.dart';
import 'package:evaluation_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets("Sans env.json, l'appli explique comment la configurer",
      (tester) async {
    await tester.pumpWidget(const ConfigManquanteApp());
    expect(find.textContaining('Configuration Supabase manquante'),
        findsOneWidget);
  });

  group('Garde de route (calculerRedirection)', () {
    String? redir(String chemin, {bool connecte = true, Role? role}) =>
        calculerRedirection(
          chemin: chemin,
          chargement: false,
          estConnecte: connecte,
          role: connecte ? role : null,
        );

    test('Visiteur non connecté : renvoyé vers /login', () {
      expect(redir('/tests', connecte: false), Routes.login);
      expect(redir('/admin', connecte: false), Routes.login);
      expect(redir('/register', connecte: false), isNull);
    });

    test('Candidat : ne peut pas ouvrir /admin (US4)', () {
      expect(redir('/admin', role: Role.candidat), Routes.tests);
      expect(redir('/login', role: Role.candidat), Routes.tests);
      expect(redir('/profil', role: Role.candidat), isNull);
    });

    test('Admin : toujours dans /admin', () {
      expect(redir('/tests', role: Role.admin), Routes.admin);
      expect(redir('/login', role: Role.admin), Routes.admin);
      expect(redir('/admin', role: Role.admin), isNull);
    });

    test('Rôle en cours de lecture : écran de chargement', () {
      expect(
        calculerRedirection(
          chemin: '/tests',
          chargement: true,
          estConnecte: true,
          role: null,
        ),
        Routes.chargement,
      );
    });
  });
}
