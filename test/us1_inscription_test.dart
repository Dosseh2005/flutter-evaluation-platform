import 'package:evaluation_app/features/auth/auth_repository.dart';
import 'package:evaluation_app/features/auth/register_page.dart';
import 'package:evaluation_app/features/auth/validateurs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Faux repository : simule la réponse du serveur sans Supabase.
class FauxAuthRepository implements AuthRepository {
  FauxAuthRepository({this.erreur});

  /// Si non nul, l'inscription échoue avec ce message.
  final String? erreur;

  /// Dernières données reçues par [inscrire].
  Map<String, Object>? recu;

  @override
  Future<ResultatInscription> inscrire({
    required String nom,
    required String prenom,
    required String email,
    required String motDePasse,
    required int age,
    required String adresse,
    required String motivation,
  }) async {
    recu = {'nom': nom, 'email': email, 'age': age, 'motivation': motivation};
    if (erreur != null) throw ErreurAuth(erreur!);
    return ResultatInscription.connecte;
  }

  @override
  Future<void> connecter({required String email, required String motDePasse}) async {}

  @override
  Future<void> deconnecter() async {}
}

Future<FauxAuthRepository> ouvrirInscription(
  WidgetTester tester, {
  String? erreur,
}) async {
  final faux = FauxAuthRepository(erreur: erreur);
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(faux)],
    child: const MaterialApp(home: RegisterPage()),
  ));
  return faux;
}

Future<void> remplirFormulaire(WidgetTester tester) async {
  Future<void> saisir(String label, String texte) =>
      tester.enterText(find.widgetWithText(TextFormField, label), texte);

  await saisir('Nom *', 'Dupont');
  await saisir('Prénom *', 'Marie');
  await saisir('Email *', 'marie.dupont@exemple.fr');
  await saisir('Âge *', '22');
  await saisir('Adresse postale *', '1 rue de Paris, 75001 Paris');
  await saisir('Mot de passe *', 'motdepasse');
  await saisir('Confirmer le mot de passe *', 'motdepasse');
  await tester.tap(find.text('Motivation *'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Reconversion').last);
  await tester.pumpAndSettle();
}

void main() {
  group('Validateurs', () {
    test('Champ obligatoire', () {
      expect(obligatoire(''), isNotNull);
      expect(obligatoire('   '), isNotNull);
      expect(obligatoire('Dupont'), isNull);
    });

    test('Email', () {
      expect(validerEmail(''), isNotNull);
      expect(validerEmail('marie'), 'Email invalide');
      expect(validerEmail('marie@exemple'), 'Email invalide');
      expect(validerEmail('marie.dupont@exemple.fr'), isNull);
    });

    test('Âge entre 15 et 99', () {
      expect(validerAge(''), isNotNull);
      expect(validerAge('abc'), isNotNull);
      expect(validerAge('14'), isNotNull);
      expect(validerAge('100'), isNotNull);
      expect(validerAge('15'), isNull);
      expect(validerAge('99'), isNull);
    });

    test('Mot de passe et confirmation', () {
      expect(validerMotDePasse('court'), isNotNull);
      expect(validerMotDePasse('12345678'), isNull);
      expect(validerConfirmation('autre', '12345678'), isNotNull);
      expect(validerConfirmation('12345678', '12345678'), isNull);
    });

    test('Motivation : uniquement les 3 choix de la base', () {
      expect(validerMotivation(null), isNotNull);
      expect(validerMotivation('Autre'), isNotNull);
      for (final m in motivations) {
        expect(validerMotivation(m), isNull);
      }
    });
  });

  group('Messages d\'erreur Supabase en français', () {
    test('Email déjà utilisé', () {
      expect(
        traduireErreurAuth(const AuthException('x', code: 'user_already_exists')),
        contains('existe déjà'),
      );
    });

    // Messages copiés des vraies réponses du serveur Supabase (erreur 500).
    test('Doublon Nom + Email refusé par la base', () {
      expect(
        traduireErreurAuth(AuthRetryableFetchException(
          message: '{"code":"23505","message":"duplicate key value violates '
              'unique constraint \\"profiles_nom_email_key\\""}',
          statusCode: '500',
        )),
        'Un compte existe déjà avec ce nom et cet email.',
      );
    });

    test('Information invalide refusée par la base (âge, motivation…)', () {
      expect(
        traduireErreurAuth(AuthRetryableFetchException(
          message: '{"code":"23514","message":"new row for relation '
              '\\"profiles\\" violates check constraint '
              '\\"profiles_age_check\\""}',
          statusCode: '500',
        )),
        contains('manquante ou invalide'),
      );
    });

    test('Serveur injoignable', () {
      expect(
        traduireErreurAuth(
            AuthRetryableFetchException(message: 'ClientException: Failed to fetch')),
        contains('Impossible de joindre le serveur'),
      );
    });

    test('Mauvais identifiants', () {
      expect(
        traduireErreurAuth(const AuthException('x', code: 'invalid_credentials')),
        'Email ou mot de passe incorrect.',
      );
    });
  });

  group('Écran d\'inscription', () {
    testWidgets('Formulaire vide : erreurs affichées, rien envoyé',
        (tester) async {
      final faux = await ouvrirInscription(tester);
      await tester.tap(find.text("S'inscrire"));
      await tester.pump();

      expect(find.text('Le nom est obligatoire'), findsOneWidget);
      expect(find.text('Le prénom est obligatoire'), findsOneWidget);
      expect(find.text("L'email est obligatoire"), findsOneWidget);
      expect(find.text('Choisissez une motivation'), findsOneWidget);
      expect(faux.recu, isNull);
    });

    testWidgets('Formulaire complet : inscription envoyée', (tester) async {
      final faux = await ouvrirInscription(tester);
      await remplirFormulaire(tester);
      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();

      expect(faux.recu, {
        'nom': 'Dupont',
        'email': 'marie.dupont@exemple.fr',
        'age': 22,
        'motivation': 'Reconversion',
      });
    });

    testWidgets('Erreur du serveur : message affiché', (tester) async {
      await ouvrirInscription(tester,
          erreur: 'Un compte existe déjà avec cet email.');
      await remplirFormulaire(tester);
      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();

      expect(find.text('Un compte existe déjà avec cet email.'), findsOneWidget);
    });
  });
}
