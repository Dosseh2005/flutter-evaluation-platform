import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';

/// Profil d'un candidat (table `profiles`).
class Profil {
  /// Crée un profil.
  const Profil({
    required this.nom,
    required this.prenom,
    required this.email,
    this.age,
    this.adresse,
    this.motivation,
  });

  /// Lit une ligne de la table `profiles`.
  factory Profil.fromJson(Map<String, dynamic> json) => Profil(
        nom: json['nom'] as String,
        prenom: json['prenom'] as String,
        email: json['email'] as String,
        age: json['age'] as int?,
        adresse: json['adresse'] as String?,
        motivation: json['motivation'] as String?,
      );

  /// Nom (lecture seule).
  final String nom;

  /// Prénom (lecture seule).
  final String prenom;

  /// Email (lecture seule).
  final String email;

  /// Âge (lecture seule).
  final int? age;

  /// Adresse postale (modifiable).
  final String? adresse;

  /// Motivation (modifiable).
  final String? motivation;
}

/// Un test passé par le candidat.
class ScoreTest {
  /// Crée un score.
  const ScoreTest({
    required this.discipline,
    required this.score,
    required this.total,
    required this.date,
  });

  /// Lit une ligne de `tentatives` avec sa discipline.
  factory ScoreTest.fromJson(Map<String, dynamic> json) => ScoreTest(
        discipline: (json['disciplines'] as Map)['nom'] as String,
        score: json['score'] as int,
        total: json['total'] as int,
        date: DateTime.parse(json['fin'] as String).toLocal(),
      );

  /// Nom de la discipline.
  final String discipline;

  /// Bonnes réponses.
  final int score;

  /// Nombre de questions.
  final int total;

  /// Date de fin du test.
  final DateTime date;
}

/// Lecture et mise à jour du profil du candidat connecté (US3).
///
/// La base (RLS) garantit qu'un candidat ne lit et ne modifie QUE son
/// profil, et seulement les colonnes `adresse` et `motivation`.
class ProfilRepository {
  String get _uid => supabase.auth.currentUser!.id;

  /// Profil du candidat connecté.
  Future<Profil> monProfil() async {
    final ligne =
        await supabase.from('profiles').select().eq('id', _uid).single();
    return Profil.fromJson(ligne);
  }

  /// Met à jour l'adresse postale et la motivation.
  Future<void> mettreAJour({
    required String adresse,
    required String motivation,
  }) async {
    await supabase
        .from('profiles')
        .update({'adresse': adresse.trim(), 'motivation': motivation})
        .eq('id', _uid);
  }

  /// Scores des tests terminés, du plus récent au plus ancien.
  Future<List<ScoreTest>> mesScores() async {
    final lignes = await supabase
        .from('tentatives')
        .select('score, total, fin, disciplines(nom)')
        .eq('candidat_id', _uid)
        .not('fin', 'is', null)
        .order('fin', ascending: false);
    return lignes.map(ScoreTest.fromJson).toList();
  }
}

/// Fournit le [ProfilRepository].
final profilRepositoryProvider =
    Provider<ProfilRepository>((ref) => ProfilRepository());
