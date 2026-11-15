import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import 'question.dart';

/// Gestion des questions par l'administrateur (US5).
///
/// La base n'autorise ces opérations qu'à l'admin (règles RLS et
/// vérification `is_admin()` dans les fonctions SQL).
class QuestionsRepository {
  /// Questions d'une discipline, avec leurs choix, dans l'ordre du test.
  Future<List<Question>> lister(int disciplineId) async {
    final lignes = await supabase
        .from('questions')
        .select('id, enonce, type, temps_limite_sec, ordre, '
            'choix(id, texte, est_correct)')
        .eq('discipline_id', disciplineId)
        .order('ordre')
        .order('id');
    return lignes.map(Question.depuisBase).toList();
  }

  /// Crée la question (si `question.id` est null) ou la modifie.
  /// Les choix sont remplacés en une seule transaction côté serveur.
  Future<void> enregistrer(int disciplineId, Question question) async {
    await supabase.rpc('enregistrer_question', params: {
      'p_question_id': question.id,
      'p_discipline_id': disciplineId,
      'p_question': question.toJson(),
    });
  }

  /// Supprime une question (ses choix sont supprimés avec elle).
  Future<void> supprimer(int questionId) async {
    await supabase.from('questions').delete().eq('id', questionId);
  }

  /// Remplace toutes les questions d'une discipline par [questions]
  /// (import JSON). Tout ou rien : si une question est invalide, rien
  /// n'est modifié. Renvoie le nombre de questions importées.
  Future<int> reinitialiser(int disciplineId, List<Question> questions) async {
    final n = await supabase.rpc('reinitialiser_discipline', params: {
      'p_discipline_id': disciplineId,
      'p_questions': [for (final q in questions) q.toJson()],
    });
    return n as int;
  }
}

/// Fournit le [QuestionsRepository].
final questionsRepositoryProvider =
    Provider<QuestionsRepository>((ref) => QuestionsRepository());
