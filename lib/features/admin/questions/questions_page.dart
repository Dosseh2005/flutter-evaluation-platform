import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/disciplines.dart';
import '../../../core/erreurs.dart';
import '../../../core/theme.dart';
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
              texte:
                  'Aucune discipline en base : exécutez supabase/schema.sql.',
            ),
          );
        }
        return DefaultTabController(
          length: disciplines.length,
          child: AdminScaffold(
            titre: 'Questions',
            corps: Column(
              children: [
                Container(
                  color: Couleurs.surface,
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    margesPage(context).left,
                    0,
                    margesPage(context).right,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (MediaQuery.sizeOf(context).width >= largeurOrdinateur)
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: const EnTete(
                            titre: 'Questions',
                            description:
                                'Les questions sont posées aux '
                                'candidats dans l\'ordre de cette liste.',
                          ),
                        ),
                      TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [for (final d in disciplines) Tab(text: d.nom)],
                      ),
                    ],
                  ),
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
    _questions = ref
        .read(questionsRepositoryProvider)
        .lister(widget.discipline.id);
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
      afficherMessage(
        messenger,
        'Fichier invalide : ${e.message}',
        erreur: true,
      );
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
        largeurMax: 1080,
        child: ListView(
          padding: margesPage(context),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Text(
                  '${questions.length} question(s)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _importer,
                      icon: const Icon(Icons.upload_file, size: 20),
                      label: const Text('Réinitialiser via JSON'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _ouvrirFormulaire(),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Ajouter une question'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (questions.isEmpty)
              const Panneau(
                child: MessageCentre(
                  icone: Icons.quiz_outlined,
                  texte:
                      'Aucune question pour le moment. Ajoutez-en une ou '
                      'importez un fichier JSON.',
                ),
              )
            else
              Panneau(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < questions.length; i++) ...[
                      if (i > 0) const Divider(),
                      _LigneQuestion(
                        numero: i + 1,
                        question: questions[i],
                        modifier: () => _ouvrirFormulaire(questions[i]),
                        supprimer: () => _supprimer(questions[i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Une question de la liste : énoncé, type, temps, choix (bonnes réponses
/// marquées) et actions.
class _LigneQuestion extends StatelessWidget {
  const _LigneQuestion({
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
    final theme = Theme.of(context);
    final type = question.type == TypeQuestion.radio
        ? 'Une seule réponse'
        : 'Plusieurs réponses';
    // container: true → la question forme un bloc annoncé en entier par
    // les lecteurs d'écran (énoncé, type, temps, choix).
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '$numero. ${question.enonce}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: modifier,
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline),
                  color: Couleurs.alerte,
                  onPressed: supprimer,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Pastille(type),
                Pastille('${question.tempsLimiteSec} secondes'),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < question.choix.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        String.fromCharCode(65 + i),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Couleurs.texteSecondaire,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        question.choix[i].texte,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: question.choix[i].correct
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: question.choix[i].correct
                              ? Couleurs.reussite
                              : Couleurs.encre,
                        ),
                      ),
                    ),
                    if (question.choix[i].correct)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check,
                              size: 18,
                              color: Couleurs.reussite,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Bonne réponse',
                              style: TextStyle(
                                fontFamily: policeApp,
                                fontSize: 13,
                                color: Couleurs.reussite,
                              ),
                            ),
                          ],
                        ),
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
