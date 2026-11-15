import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/disciplines.dart';
import '../../../core/erreurs.dart';
import '../../../core/widgets.dart';
import 'question.dart';
import 'question_form_page.dart';
import 'questions_repository.dart';

/// Ouvre le sélecteur de fichiers et renvoie le contenu texte du fichier
/// .json choisi, ou `null` si l'utilisateur annule.
///
/// Placé dans un provider pour pouvoir le remplacer dans les tests.
final choisirFichierJsonProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    final fichier = await FilePicker.pickFile(
      dialogTitle: 'Choisir un fichier de questions (.json)',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (fichier == null) return null;
    return utf8.decode(await fichier.readAsBytes());
  },
);

/// Gestion des questions par discipline (US5) : un onglet par discipline,
/// avec ajout, modification, suppression et import JSON.
class QuestionsPage extends ConsumerStatefulWidget {
  /// Crée la page.
  const QuestionsPage({super.key});

  @override
  ConsumerState<QuestionsPage> createState() => _QuestionsPageState();
}

class _QuestionsPageState extends ConsumerState<QuestionsPage> {
  late Future<List<Discipline>> _disciplines;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _charger() {
    _disciplines = ref.read(disciplinesRepositoryProvider).lister();
  }

  @override
  Widget build(BuildContext context) {
    return ChargementFuture<List<Discipline>>(
      future: _disciplines,
      reessayer: () => setState(_charger),
      builder: (context, disciplines) {
        if (disciplines.isEmpty) {
          return const AdminScaffold(
            titre: 'Questions',
            corps: MessageCentre(
              icone: Icons.info_outline,
              texte: 'Aucune discipline en base : exécutez supabase/schema.sql.',
            ),
          );
        }
        return DefaultTabController(
          length: disciplines.length,
          child: AdminScaffold(
            titre: 'Questions',
            corps: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabs: [for (final d in disciplines) Tab(text: d.nom)],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final d in disciplines)
                        ListeQuestions(discipline: d, key: ValueKey(d.id)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Liste des questions d'une discipline avec ses actions.
class ListeQuestions extends ConsumerStatefulWidget {
  /// Crée la liste pour [discipline].
  const ListeQuestions({super.key, required this.discipline});

  /// Discipline affichée.
  final Discipline discipline;

  @override
  ConsumerState<ListeQuestions> createState() => _ListeQuestionsState();
}

class _ListeQuestionsState extends ConsumerState<ListeQuestions> {
  late Future<List<Question>> _questions;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _charger() {
    _questions =
        ref.read(questionsRepositoryProvider).lister(widget.discipline.id);
  }

  void _recharger() => setState(_charger);

  Future<void> _ouvrirFormulaire([Question? question]) async {
    final enregistre = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuestionFormPage(
          disciplineId: widget.discipline.id,
          nomDiscipline: widget.discipline.nom,
          question: question,
        ),
      ),
    );
    if (enregistre == true) _recharger();
  }

  /// Demande une confirmation (Oui / Annuler) avant une action destructive.
  Future<bool> _confirmer(String titre, String texte, String bouton) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titre),
        content: Text(texte),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(bouton),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _supprimer(Question question) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirmer(
      'Supprimer la question ?',
      '« ${question.enonce} »\n\nCette action est définitive.',
      'Supprimer',
    );
    if (!ok) return;
    try {
      await ref.read(questionsRepositoryProvider).supprimer(question.id!);
      afficherMessage(messenger, 'Question supprimée');
      _recharger();
    } catch (e) {
      afficherMessage(messenger, messageErreur(e), erreur: true);
    }
  }

  /// Import JSON : lit le fichier, le vérifie, demande confirmation puis
  /// remplace toutes les questions de la discipline.
  Future<void> _importer() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final contenu = await ref.read(choisirFichierJsonProvider)();
      if (contenu == null) return;
      final questions = lireFichierImport(jsonDecode(contenu));

      final ok = await _confirmer(
        'Réinitialiser « ${widget.discipline.nom} » ?',
        'Toutes les questions actuelles de cette discipline seront '
            'supprimées et remplacées par les ${questions.length} questions '
            'du fichier.',
        'Remplacer',
      );
      if (!ok) return;

      final n = await ref
          .read(questionsRepositoryProvider)
          .reinitialiser(widget.discipline.id, questions);
      afficherMessage(messenger, '$n questions importées');
      _recharger();
    } on FormatException catch (e) {
      afficherMessage(messenger, 'Fichier invalide : ${e.message}',
          erreur: true);
    } catch (e) {
      afficherMessage(messenger, messageErreur(e), erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChargementFuture<List<Question>>(
      future: _questions,
      reessayer: _recharger,
      builder: (context, questions) => ContenuCentre(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${questions.length} question(s)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () => _ouvrirFormulaire(),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une question'),
                ),
                OutlinedButton.icon(
                  onPressed: _importer,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Réinitialiser via JSON'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (questions.isEmpty)
              const MessageCentre(
                icone: Icons.quiz_outlined,
                texte: 'Aucune question pour le moment.',
              ),
            for (var i = 0; i < questions.length; i++)
              _CarteQuestion(
                numero: i + 1,
                question: questions[i],
                modifier: () => _ouvrirFormulaire(questions[i]),
                supprimer: () => _supprimer(questions[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _CarteQuestion extends StatelessWidget {
  const _CarteQuestion({
    required this.numero,
    required this.question,
    required this.modifier,
    required this.supprimer,
  });

  final int numero;
  final Question question;
  final VoidCallback modifier;
  final VoidCallback supprimer;

  @override
  Widget build(BuildContext context) {
    final type =
        question.type == TypeQuestion.radio ? 'Une réponse' : 'Plusieurs réponses';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text('$numero. ${question.enonce}',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: modifier,
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: supprimer,
                ),
              ],
            ),
            Text('$type · ${question.tempsLimiteSec} s',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            for (final c in question.choix)
              Row(
                children: [
                  Icon(
                    c.correct ? Icons.check_circle : Icons.circle_outlined,
                    size: 18,
                    color: c.correct ? Colors.green : null,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(c.texte)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
