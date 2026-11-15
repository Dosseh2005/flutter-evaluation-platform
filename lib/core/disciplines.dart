import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_client.dart';

/// Une discipline évaluée (Java, Algorithmes, HTML/CSS).
class Discipline {
  /// Crée une discipline.
  const Discipline({required this.id, required this.nom});

  /// Crée une discipline à partir d'une ligne de la table `disciplines`.
  factory Discipline.fromJson(Map<String, dynamic> json) =>
      Discipline(id: json['id'] as int, nom: json['nom'] as String);

  /// Identifiant en base.
  final int id;

  /// Nom affiché.
  final String nom;
}

/// Lecture des disciplines (lisibles par tout utilisateur connecté).
class DisciplinesRepository {
  /// Renvoie toutes les disciplines, dans l'ordre de création.
  Future<List<Discipline>> lister() async {
    final lignes = await supabase.from('disciplines').select().order('id');
    return lignes.map(Discipline.fromJson).toList();
  }
}

/// Fournit le [DisciplinesRepository].
final disciplinesRepositoryProvider =
    Provider<DisciplinesRepository>((ref) => DisciplinesRepository());
