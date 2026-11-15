import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../test/test_repository.dart';

/// Taux de réussite d'une discipline pour une année scolaire (US7).
class StatDiscipline {
  /// Crée une statistique.
  const StatDiscipline({
    required this.discipline,
    required this.nbTests,
    required this.nbReussis,
  });

  /// Lit une ligne renvoyée par la fonction SQL `stats_reussite`.
  factory StatDiscipline.fromJson(Map<String, dynamic> json) => StatDiscipline(
        discipline: json['discipline'] as String,
        nbTests: json['nb_tests'] as int,
        nbReussis: json['nb_reussis'] as int,
      );

  /// Nom de la discipline (ou « Toutes les disciplines » pour le total).
  final String discipline;

  /// Nombre de tests terminés.
  final int nbTests;

  /// Nombre de tests réussis.
  final int nbReussis;

  /// Nombre de tests échoués.
  int get nbEchoues => nbTests - nbReussis;

  /// Pourcentage de réussite (0 à 100), 0 s'il n'y a aucun test.
  double get tauxReussite => nbTests == 0 ? 0 : nbReussis * 100 / nbTests;
}

/// Camembert général : additionne les tests de toutes les disciplines.
StatDiscipline statGenerale(List<StatDiscipline> stats) => StatDiscipline(
      discipline: 'Tous les étudiants',
      nbTests: stats.fold(0, (somme, s) => somme + s.nbTests),
      nbReussis: stats.fold(0, (somme, s) => somme + s.nbReussis),
    );

/// Lecture des statistiques (réservé à l'admin : la fonction SQL ne
/// renvoie rien pour un autre utilisateur).
class StatsRepository {
  /// Taux de réussite par discipline pour l'année scolaire [annee]
  /// (ex : « 2026-2027 »). Un test est réussi à partir de 50 %.
  Future<List<StatDiscipline>> parDiscipline(String annee) async {
    final lignes = await supabase.rpc('stats_reussite', params: {
      'p_annee': annee,
      'p_seuil': seuilReussite,
    }) as List;
    return lignes
        .map((l) => StatDiscipline.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  /// Années scolaires pour lesquelles il existe au moins un test.
  Future<List<String>> annees() async {
    final lignes = await supabase.from('tentatives').select('annee_scolaire');
    return lignes.map((l) => l['annee_scolaire'] as String).toSet().toList();
  }
}

/// Fournit le [StatsRepository].
final statsRepositoryProvider =
    Provider<StatsRepository>((ref) => StatsRepository());
