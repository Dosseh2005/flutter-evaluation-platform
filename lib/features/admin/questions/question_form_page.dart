import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/erreurs.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import 'question.dart';
import 'questions_repository.dart';

/// Ligne de choix en cours d'édition dans le formulaire.
class _ChoixEdite {
  _ChoixEdite(String texte, this.correct)
    : controleur = TextEditingController(text: texte);

  final TextEditingController controleur;
  bool correct;
}

/// Formulaire de création / modification d'une question (US5).
///
/// Renvoie `true` (via `Navigator.pop`) si la question a été enregistrée.
class QuestionFormPage extends ConsumerStatefulWidget {
  /// Crée le formulaire pour la discipline [disciplineId]. Si [question]
  /// est fournie, ses valeurs sont pré-remplies (modification).
  const QuestionFormPage({
    super.key,
    required this.disciplineId,
    required this.nomDiscipline,
    this.question,
  });

  /// Discipline de la question.
  final int disciplineId;

  /// Nom de la discipline (affiché dans le titre).
  final String nomDiscipline;

  /// Question à modifier, ou `null` pour une nouvelle question.
  final Question? question;

  @override
  ConsumerState<QuestionFormPage> createState() => _QuestionFormPageState();
}

class _QuestionFormPageState extends ConsumerState<QuestionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _enonce;
  late final TextEditingController _temps;
  late TypeQuestion _type;
  late final List<_ChoixEdite> _choix;
  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _enonce = TextEditingController(text: q?.enonce ?? '');
    _temps = TextEditingController(text: '${q?.tempsLimiteSec ?? 30}');
    _type = q?.type ?? TypeQuestion.radio;
    _choix = q == null
        ? [_ChoixEdite('', true), _ChoixEdite('', false)]
        : [for (final c in q.choix) _ChoixEdite(c.texte, c.correct)];
  }

  @override
  void dispose() {
    _enonce.dispose();
    _temps.dispose();
    for (final c in _choix) {
      c.controleur.dispose();
    }
    super.dispose();
  }

  /// Coche / décoche une bonne réponse. En mode radio, cocher un choix
  /// décoche automatiquement les autres.
  void _basculerCorrect(int index, bool valeur) {
    setState(() {
      if (_type == TypeQuestion.radio && valeur) {
        for (final c in _choix) {
          c.correct = false;
        }
      }
      _choix[index].correct = valeur;
    });
  }

  /// Change le type ; en passant en radio, on ne garde que la première
  /// bonne réponse.
  void _changerType(TypeQuestion type) {
    setState(() {
      _type = type;
      if (type == TypeQuestion.radio) {
        var dejaUne = false;
        for (final c in _choix) {
          if (c.correct && dejaUne) c.correct = false;
          if (c.correct) dejaUne = true;
        }
      }
    });
  }

  Question _questionSaisie() => Question(
    id: widget.question?.id,
    enonce: _enonce.text.trim(),
    type: _type,
    tempsLimiteSec: int.tryParse(_temps.text) ?? 0,
    choix: [
      for (final c in _choix)
        Choix(texte: c.controleur.text.trim(), correct: c.correct),
    ],
  );

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final couleurErreur = Theme.of(context).colorScheme.error;
    final question = _questionSaisie();

    final erreurs = verifierQuestion(question);
    if (erreurs.isNotEmpty) {
      afficherMessage(
        messenger,
        erreurs.join('\n'),
        erreur: true,
        couleurErreur: couleurErreur,
      );
      return;
    }

    setState(() => _envoiEnCours = true);
    try {
      await ref
          .read(questionsRepositoryProvider)
          .enregistrer(widget.disciplineId, question);
      if (!mounted) return;
      afficherMessage(messenger, 'Question enregistrée');
      Navigator.of(context).pop(true);
    } catch (e) {
      afficherMessage(
        messenger,
        messageErreur(e),
        erreur: true,
        couleurErreur: couleurErreur,
      );
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modification = widget.question != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${modification ? 'Modifier' : 'Nouvelle'} question – '
          '${widget.nomDiscipline}',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: margesPage(context),
          children: [
            ContenuCentre(
              largeurMax: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Panneau(
                    titre: 'La question',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _enonce,
                          decoration: const InputDecoration(
                            labelText: 'Énoncé *',
                          ),
                          maxLines: 3,
                          minLines: 1,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? "L'énoncé est obligatoire"
                              : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<TypeQuestion>(
                          initialValue: _type,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Type *',
                          ),
                          items: [
                            for (final t in TypeQuestion.values)
                              DropdownMenuItem(
                                value: t,
                                child: Text(t.libelle),
                              ),
                          ],
                          onChanged: (t) => _changerType(t!),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _temps,
                          decoration: const InputDecoration(
                            labelText: 'Temps limite (secondes) *',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                              ? 'Le temps doit être supérieur à 0'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Panneau(
                    titre: 'Réponses proposées',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _type == TypeQuestion.radio
                              ? 'Cochez la bonne réponse (une seule).'
                              : 'Cochez toutes les bonnes réponses.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Couleurs.texteSecondaire),
                        ),
                        const SizedBox(height: 16),
                        for (var i = 0; i < _choix.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Tooltip(
                                  message: 'Bonne réponse',
                                  child: Checkbox(
                                    value: _choix[i].correct,
                                    activeColor: Couleurs.reussite,
                                    onChanged: (v) =>
                                        _basculerCorrect(i, v ?? false),
                                  ),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _choix[i].controleur,
                                    decoration: InputDecoration(
                                      labelText: 'Choix ${i + 1}',
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Choix vide'
                                        : null,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Supprimer ce choix',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: _choix.length <= 2
                                      ? null
                                      : () => setState(() {
                                          _choix
                                              .removeAt(i)
                                              .controleur
                                              .dispose();
                                        }),
                                ),
                              ],
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(
                              () => _choix.add(_ChoixEdite('', false)),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter un choix'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _envoiEnCours ? null : _enregistrer,
                        child: Text(
                          _envoiEnCours ? 'Enregistrement…' : 'Enregistrer',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
