/// Modèle d'une question et de ses choix (US5), avec les contrôles
/// appliqués avant l'enregistrement ou l'import JSON.
library;

/// Type de question : une seule ou plusieurs bonnes réponses.
enum TypeQuestion {
  /// RadioButton : exactement une bonne réponse.
  radio('Une seule réponse (RadioButton)'),

  /// Checkbox : une ou plusieurs bonnes réponses.
  checkbox('Plusieurs réponses (Checkbox)');

  const TypeQuestion(this.libelle);

  /// Texte affiché dans le formulaire.
  final String libelle;

  /// Lit le type depuis la base ou le JSON (`"radio"` / `"checkbox"`).
  static TypeQuestion depuis(String? valeur) => switch (valeur) {
        'radio' => TypeQuestion.radio,
        'checkbox' => TypeQuestion.checkbox,
        _ => throw FormatException('type inconnu « $valeur »'),
      };
}

/// Un choix de réponse.
class Choix {
  /// Crée un choix.
  const Choix({required this.texte, required this.correct});

  /// Texte du choix.
  final String texte;

  /// Vrai si c'est une bonne réponse.
  final bool correct;

  /// Format JSON commun à la base et au fichier d'import.
  Map<String, dynamic> toJson() => {'texte': texte, 'correct': correct};
}

/// Une question d'une discipline.
class Question {
  /// Crée une question. [id] est `null` pour une nouvelle question.
  const Question({
    this.id,
    required this.enonce,
    required this.type,
    required this.tempsLimiteSec,
    required this.choix,
  });

  /// Lit une ligne de la table `questions` avec ses `choix`
  /// (`select('*, choix(*)')`).
  factory Question.depuisBase(Map<String, dynamic> json) {
    final choix = (json['choix'] as List)
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return Question(
      id: json['id'] as int,
      enonce: json['enonce'] as String,
      type: TypeQuestion.depuis(json['type'] as String),
      tempsLimiteSec: json['temps_limite_sec'] as int,
      choix: [
        for (final c in choix)
          Choix(texte: c['texte'] as String, correct: c['est_correct'] as bool),
      ],
    );
  }

  /// Lit une question du fichier d'import JSON (voir
  /// `data/questions_java.json`). Lève une [FormatException] si un champ
  /// manque ou n'a pas le bon type.
  factory Question.depuisFichier(Object? json, int numero) {
    if (json is! Map) {
      throw FormatException('question $numero : objet attendu');
    }
    final choix = json['choix'];
    if (choix is! List) {
      throw FormatException('question $numero : liste « choix » manquante');
    }
    final temps = json['temps_limite_sec'];
    if (temps is! int) {
      throw FormatException(
          'question $numero : « temps_limite_sec » doit être un nombre entier');
    }
    return Question(
      enonce: (json['enonce'] ?? '').toString(),
      type: TypeQuestion.depuis(json['type']?.toString()),
      tempsLimiteSec: temps,
      choix: [
        for (final c in choix)
          if (c is Map)
            Choix(
              texte: (c['texte'] ?? '').toString(),
              correct: c['correct'] == true,
            )
          else
            throw FormatException('question $numero : choix invalide'),
      ],
    );
  }

  /// Identifiant en base (`null` si pas encore enregistrée).
  final int? id;

  /// Énoncé de la question.
  final String enonce;

  /// Radio (une bonne réponse) ou Checkbox (plusieurs).
  final TypeQuestion type;

  /// Temps limite pour répondre, en secondes.
  final int tempsLimiteSec;

  /// Choix de réponse, dans l'ordre d'affichage.
  final List<Choix> choix;

  /// Nombre de bonnes réponses.
  int get nbBonnes => choix.where((c) => c.correct).length;

  /// Format JSON envoyé aux fonctions SQL (identique au fichier d'import).
  Map<String, dynamic> toJson() => {
        'enonce': enonce.trim(),
        'type': type.name,
        'temps_limite_sec': tempsLimiteSec,
        'choix': [for (final c in choix) c.toJson()],
      };
}

/// Vérifie une question avant de l'enregistrer.
///
/// Renvoie la liste des problèmes (vide si tout est correct). Mêmes règles
/// que la fonction SQL `verifier_question` :
/// énoncé non vide, temps > 0, au moins 2 choix non vides, au moins une
/// bonne réponse, exactement une si la question est de type radio.
List<String> verifierQuestion(Question q) {
  final erreurs = <String>[];
  if (q.enonce.trim().isEmpty) erreurs.add("L'énoncé est vide");
  if (q.tempsLimiteSec <= 0) {
    erreurs.add('Le temps limite doit être supérieur à 0');
  }
  if (q.choix.length < 2) erreurs.add('Il faut au moins 2 choix');
  if (q.choix.any((c) => c.texte.trim().isEmpty)) {
    erreurs.add('Un choix est vide');
  }
  if (q.nbBonnes == 0) erreurs.add('Il faut au moins une bonne réponse');
  if (q.type == TypeQuestion.radio && q.nbBonnes > 1) {
    erreurs.add('Une question à réponse unique doit avoir exactement une '
        'bonne réponse');
  }
  return erreurs;
}

/// Lit tout un fichier d'import : `{ "questions": [ ... ] }`.
///
/// Lève une [FormatException] avec un message clair si le fichier est mal
/// formé ou si une question ne respecte pas les règles de [verifierQuestion].
List<Question> lireFichierImport(Object? json) {
  if (json is! Map || json['questions'] is! List) {
    throw const FormatException(
        'le fichier doit contenir une liste « questions »');
  }
  final liste = json['questions'] as List;
  if (liste.isEmpty) {
    throw const FormatException('la liste « questions » est vide');
  }
  final questions = <Question>[];
  for (var i = 0; i < liste.length; i++) {
    final q = Question.depuisFichier(liste[i], i + 1);
    final erreurs = verifierQuestion(q);
    if (erreurs.isNotEmpty) {
      throw FormatException('question ${i + 1} : ${erreurs.first}');
    }
    questions.add(q);
  }
  return questions;
}
