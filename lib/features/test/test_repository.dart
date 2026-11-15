import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';

/// Un test proposé au candidat (une ligne de la fonction SQL `mes_tests`).
class TestDisponible {
  /// Crée un test disponible.
  const TestDisponible({
    required this.disciplineId,
    required this.discipline,
    required this.nbQuestions,
    this.tentativeId,
    this.score,
    this.total,
    this.termine = false,
  });

  /// Lit une ligne renvoyée par `mes_tests()`.
  factory TestDisponible.fromJson(Map<String, dynamic> json) => TestDisponible(
    disciplineId: json['discipline_id'] as int,
    discipline: json['discipline'] as String,
    nbQuestions: json['nb_questions'] as int,
    tentativeId: json['tentative_id'] as int?,
    score: json['score'] as int?,
    total: json['total'] as int?,
    termine: json['termine'] as bool? ?? false,
  );

  /// Identifiant de la discipline.
  final int disciplineId;

  /// Nom de la discipline.
  final String discipline;

  /// Nombre de questions du test.
  final int nbQuestions;

  /// Tentative du candidat (`null` s'il n'a jamais commencé ce test).
  final int? tentativeId;

  /// Score obtenu (si terminé).
  final int? score;

  /// Nombre total de questions de la tentative.
  final int? total;

  /// Vrai si le test a déjà été passé jusqu'au bout.
  final bool termine;

  /// Vrai si le test a été commencé mais pas terminé (page fermée…).
  bool get enCours => tentativeId != null && !termine;
}

/// Une question telle que le candidat la voit : SANS les bonnes réponses.
class QuestionTest {
  /// Crée une question de test.
  const QuestionTest({
    required this.id,
    required this.enonce,
    required this.plusieursReponses,
    required this.numero,
    required this.total,
    required this.tempsRestantSec,
    required this.choix,
  });

  /// Lit l'objet JSON renvoyé par la fonction SQL `question_suivante`.
  factory QuestionTest.fromJson(Map<String, dynamic> json) => QuestionTest(
    id: json['id'] as int,
    enonce: json['enonce'] as String,
    plusieursReponses: json['type'] == 'checkbox',
    numero: json['numero'] as int,
    total: json['total'] as int,
    tempsRestantSec: json['temps_restant_sec'] as int,
    choix: [
      for (final c in (json['choix'] as List? ?? const []))
        (id: c['id'] as int, texte: c['texte'] as String),
    ],
  );

  /// Identifiant de la question.
  final int id;

  /// Énoncé.
  final String enonce;

  /// Vrai pour une question Checkbox (plusieurs réponses possibles).
  final bool plusieursReponses;

  /// Numéro de la question dans le test (1, 2, 3…).
  final int numero;

  /// Nombre total de questions.
  final int total;

  /// Secondes restantes, calculées par le serveur (le chrono ne repart
  /// pas de zéro si la page est rechargée).
  final int tempsRestantSec;

  /// Choix proposés (identifiant + texte).
  final List<({int id, String texte})> choix;
}

/// Passage d'un test (US2). Tout est contrôlé par le serveur : un seul
/// passage par test, temps limite, correction.
class TestRepository {
  /// Les tests du candidat connecté, avec leur état.
  Future<List<TestDisponible>> mesTests() async {
    final lignes = await supabase.rpc('mes_tests') as List;
    return lignes
        .map((l) => TestDisponible.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  /// Démarre le test d'une discipline et renvoie l'id de la tentative.
  /// Refusé par le serveur si le test a déjà été passé.
  Future<int> commencer(int disciplineId) async => await supabase.rpc(
    'commencer_test',
    params: {'p_discipline_id': disciplineId},
  ) as int;

  /// Question suivante, ou `null` quand le test est terminé (le serveur
  /// calcule alors le score).
  Future<QuestionTest?> questionSuivante(int tentativeId) async {
    final json = await supabase.rpc(
      'question_suivante',
      params: {'p_tentative_id': tentativeId},
    );
    return json == null
        ? null
        : QuestionTest.fromJson(json as Map<String, dynamic>);
  }

  /// Envoie la réponse du candidat (liste vide = pas de réponse).
  Future<void> repondre(int tentativeId, int questionId, List<int> choixIds) =>
      supabase.rpc(
        'repondre',
        params: {
          'p_tentative_id': tentativeId,
          'p_question_id': questionId,
          'p_choix_ids': choixIds,
        },
      );

  /// Score final d'une tentative terminée.
  Future<({int score, int total})> resultat(int tentativeId) async {
    final ligne = await supabase
        .from('tentatives')
        .select('score, total')
        .eq('id', tentativeId)
        .single();
    return (score: ligne['score'] as int, total: ligne['total'] as int);
  }
}

/// Fournit le [TestRepository].
final testRepositoryProvider = Provider<TestRepository>(
  (ref) => TestRepository(),
);

/// Pourcentage de réussite minimum pour qu'un test soit « réussi »
/// (même valeur que `p_seuil` dans la fonction SQL `stats_reussite`).
const seuilReussite = 0.5;

/// Vrai si [score] sur [total] atteint le [seuilReussite].
bool estReussi(int score, int total) =>
    total > 0 && score / total >= seuilReussite;
