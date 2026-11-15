import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_home_page.dart';
import '../features/admin/questions/questions_page.dart';
import '../features/admin/statistiques/statistiques_page.dart';
import '../features/admin/tableau_de_bord/tableau_de_bord_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/candidat/profil_page.dart';
import '../features/candidat/tests_page.dart';
import '../features/test/test_page.dart';
import 'session.dart';

/// Noms des routes, pour éviter les fautes de frappe dans les `context.go`.
abstract final class Routes {
  static const chargement = '/chargement';
  static const login = '/login';
  static const register = '/register';
  static const tests = '/tests';
  static const profil = '/profil';
  static const admin = '/admin';
  static const adminQuestions = '/admin/questions';
  static const adminTableauDeBord = '/admin/tableau-de-bord';
  static const adminStatistiques = '/admin/statistiques';

  /// Page de passage du test d'une discipline, ex : `/test/2`.
  static String test(int disciplineId) => '/test/$disciplineId';
}

/// Routes accessibles sans être connecté.
const _routesPubliques = {Routes.login, Routes.register};

/// Fournit le router de l'application.
final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);

  return GoRouter(
    initialLocation: Routes.tests,
    refreshListenable: session,
    redirect: (context, state) => calculerRedirection(
      chemin: state.matchedLocation,
      chargement: session.chargement,
      estConnecte: session.estConnecte,
      role: session.role,
    ),
    routes: [
      GoRoute(
        path: Routes.chargement,
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginPage()),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(path: Routes.tests, builder: (context, state) => const TestsPage()),
      GoRoute(path: Routes.profil, builder: (context, state) => const ProfilPage()),
      GoRoute(
        path: '/test/:disciplineId',
        builder: (context, state) => TestPage(
          disciplineId: int.parse(state.pathParameters['disciplineId']!),
        ),
      ),
      GoRoute(
        path: Routes.admin,
        builder: (context, state) => const AdminHomePage(),
      ),
      GoRoute(
        path: Routes.adminQuestions,
        builder: (context, state) => const QuestionsPage(),
      ),
      GoRoute(
        path: Routes.adminTableauDeBord,
        builder: (context, state) => const TableauDeBordPage(),
      ),
      GoRoute(
        path: Routes.adminStatistiques,
        builder: (context, state) => const StatistiquesPage(),
      ),
    ],
  );
});

/// Décide vers quelle page renvoyer l'utilisateur (garde de route).
///
/// Renvoie `null` si l'utilisateur a le droit de rester sur [chemin].
/// - pas connecté → seulement /login et /register ;
/// - connecté → jamais sur /login ou /register ;
/// - candidat → jamais sur /admin (US4) ; admin → toujours sous /admin.
///
/// Fonction séparée (sans Supabase) pour pouvoir la tester facilement.
String? calculerRedirection({
  required String chemin,
  required bool chargement,
  required bool estConnecte,
  required Role? role,
}) {
  final estPublique = _routesPubliques.contains(chemin);

  if (!estConnecte) return estPublique ? null : Routes.login;

  // Connecté mais rôle pas encore lu : on attend sur l'écran de chargement.
  if (chargement || role == null) {
    return chemin == Routes.chargement ? null : Routes.chargement;
  }

  final accueil = role == Role.admin ? Routes.admin : Routes.tests;
  final estAdminRoute = chemin.startsWith(Routes.admin);

  if (estPublique || chemin == Routes.chargement) return accueil;
  if (role == Role.candidat && estAdminRoute) return Routes.tests;
  if (role == Role.admin && !estAdminRoute) return Routes.admin;
  return null;
}
