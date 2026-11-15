import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/erreurs.dart';
import '../../core/router.dart';
import '../../core/widgets.dart';
import 'test_repository.dart';

/// Passage du test d'une discipline (US2).
///
/// Déroulement :
/// 1. on retrouve la tentative du candidat (démarrée par « Commencer »
///    dans « Mes tests ») ;
/// 2. on affiche une question à la fois avec son compte à rebours ;
/// 3. au clic sur « Valider » ou quand le temps est écoulé, la réponse
///    est envoyée au serveur, qui la corrige ;
/// 4. quand il n'y a plus de question, on affiche le score.
class TestPage extends ConsumerStatefulWidget {
  /// Crée la page de test pour la discipline [disciplineId].
  const TestPage({super.key, required this.disciplineId});

  /// Identifiant de la discipline (table `disciplines`).
  final int disciplineId;

  @override
  ConsumerState<TestPage> createState() => _TestPageState();
}

class _TestPageState extends ConsumerState<TestPage> {
  String _discipline = '';
  int? _tentativeId;
  QuestionTest? _question;
  final Set<int> _selection = {};
  int _restant = 0;
  Timer? _chrono;
  bool _envoiEnCours = false;
  ({int score, int total})? _resultat;
  String? _erreur;

  TestRepository get _repo => ref.read(testRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  @override
  void dispose() {
    _chrono?.cancel();
    super.dispose();
  }

  /// Étape 1 : retrouver ou créer la tentative.
  Future<void> _demarrer() async {
    try {
      final tests = await _repo.mesTests();
      final test =
          tests.firstWhere((t) => t.disciplineId == widget.disciplineId);
      _discipline = test.discipline;
      if (test.termine) {
        _afficherResultat(test.tentativeId!);
        return;
      }
      // Cette page ne démarre JAMAIS un test : seul le bouton « Commencer »
      // de « Mes tests » le fait, après confirmation. Arriver ici par
      // erreur (retour arrière, adresse tapée…) ne consomme donc pas le
      // passage unique.
      if (test.tentativeId == null) {
        if (!mounted) return;
        setState(() => _erreur = "Ce test n'a pas encore été commencé. "
            'Utilisez le bouton « Commencer » depuis « Mes tests ».');
        return;
      }
      _tentativeId = test.tentativeId;
      await _questionSuivante();
    } catch (e) {
      _afficherErreur(e);
    }
  }

  /// Étape 2 : demander la question suivante au serveur.
  Future<void> _questionSuivante() async {
    final question = await _repo.questionSuivante(_tentativeId!);
    if (!mounted) return;
    if (question == null) {
      await _afficherResultat(_tentativeId!);
      return;
    }
    setState(() {
      _question = question;
      _selection.clear();
      _restant = question.tempsRestantSec;
      _envoiEnCours = false;
    });
    _lancerChrono();
  }

  /// Compte à rebours : une seconde de moins à chaque tick ; à 0 la
  /// réponse est envoyée automatiquement.
  void _lancerChrono() {
    _chrono?.cancel();
    if (_restant <= 0) {
      _valider();
      return;
    }
    _chrono = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _restant--);
      if (_restant <= 0) {
        timer.cancel();
        _valider();
      }
    });
  }

  /// Étape 3 : envoyer la réponse (ou une réponse vide si le temps est
  /// écoulé sans rien cocher), puis passer à la question suivante.
  Future<void> _valider() async {
    if (_envoiEnCours || _question == null) return;
    _chrono?.cancel();
    setState(() => _envoiEnCours = true);
    try {
      await _repo.repondre(_tentativeId!, _question!.id, _selection.toList());
    } catch (e) {
      // « Question non disponible » : réponse déjà enregistrée (double
      // clic, page rechargée…). On continue simplement.
      if (!messageErreur(e).contains('non disponible')) {
        _afficherErreur(e);
        return;
      }
    }
    try {
      await _questionSuivante();
    } catch (e) {
      _afficherErreur(e);
    }
  }

  /// Étape 4 : afficher le score final.
  Future<void> _afficherResultat(int tentativeId) async {
    final resultat = await _repo.resultat(tentativeId);
    if (!mounted) return;
    setState(() {
      _question = null;
      _resultat = resultat;
    });
  }

  void _afficherErreur(Object e) {
    if (!mounted) return;
    _chrono?.cancel();
    setState(() => _erreur = messageErreur(e));
  }

  void _choisir(int choixId, bool coche) {
    setState(() {
      if (!_question!.plusieursReponses) _selection.clear();
      coche ? _selection.add(choixId) : _selection.remove(choixId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget corps;
    if (_erreur != null) {
      corps = MessageCentre(
        icone: Icons.error_outline,
        texte: _erreur!,
        action: FilledButton(
          onPressed: () => context.go(Routes.tests),
          child: const Text('Retour à mes tests'),
        ),
      );
    } else if (_resultat != null) {
      corps = _EcranResultat(
        discipline: _discipline,
        score: _resultat!.score,
        total: _resultat!.total,
      );
    } else if (_question == null) {
      corps = const Center(child: CircularProgressIndicator());
    } else {
      corps = _EcranQuestion(
        question: _question!,
        restant: _restant,
        selection: _selection,
        envoiEnCours: _envoiEnCours,
        choisir: _choisir,
        valider: _valider,
      );
    }

    // Pendant le test, pas de bouton retour : le chrono continue côté
    // serveur même si on quitte la page.
    return PopScope(
      canPop: _resultat != null || _erreur != null,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(_discipline.isEmpty ? 'Test' : 'Test $_discipline'),
        ),
        body: corps,
      ),
    );
  }
}

class _EcranQuestion extends StatelessWidget {
  const _EcranQuestion({
    required this.question,
    required this.restant,
    required this.selection,
    required this.envoiEnCours,
    required this.choisir,
    required this.valider,
  });

  final QuestionTest question;
  final int restant;
  final Set<int> selection;
  final bool envoiEnCours;
  final void Function(int choixId, bool coche) choisir;
  final VoidCallback valider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgent = restant <= 5;
    final derniere = question.numero >= question.total;

    return ContenuCentre(
      largeurMax: 700,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Question ${question.numero}/${question.total}',
                    style: theme.textTheme.titleMedium),
              ),
              // Simple affichage (pas un Chip : un Chip est annoncé comme
              // une case à cocher par les lecteurs d'écran).
              Semantics(
                label: 'Temps restant : $restant secondes',
                excludeSemantics: true,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: urgent
                            ? theme.colorScheme.error
                            : theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 18,
                          color: urgent ? theme.colorScheme.error : null),
                      const SizedBox(width: 6),
                      Text(
                        '$restant s',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: urgent ? theme.colorScheme.error : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: question.numero / question.total),
          const SizedBox(height: 24),
          Text(question.enonce, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            question.plusieursReponses
                ? 'Plusieurs réponses possibles'
                : 'Une seule réponse',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (question.plusieursReponses)
            for (final c in question.choix)
              CheckboxListTile(
                value: selection.contains(c.id),
                title: Text(c.texte),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged:
                    envoiEnCours ? null : (v) => choisir(c.id, v ?? false),
              )
          else
            RadioGroup<int>(
              groupValue: selection.isEmpty ? null : selection.first,
              onChanged: (v) {
                if (!envoiEnCours && v != null) choisir(v, true);
              },
              child: Column(
                children: [
                  for (final c in question.choix)
                    RadioListTile<int>(value: c.id, title: Text(c.texte)),
                ],
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: envoiEnCours || selection.isEmpty ? null : valider,
            child: Text(envoiEnCours
                ? 'Envoi…'
                : derniere
                    ? 'Valider et terminer'
                    : 'Valider'),
          ),
        ],
      ),
    );
  }
}

class _EcranResultat extends StatelessWidget {
  const _EcranResultat({
    required this.discipline,
    required this.score,
    required this.total,
  });

  final String discipline;
  final int score;
  final int total;

  @override
  Widget build(BuildContext context) {
    final reussi = estReussi(score, total);
    final pourcentage = total == 0 ? 0 : (score * 100 / total).round();
    return MessageCentre(
      icone: reussi ? Icons.emoji_events_outlined : Icons.flag_outlined,
      texte: 'Test $discipline terminé !\n\n'
          'Votre score : $score / $total ($pourcentage %)\n'
          '${reussi ? 'Test réussi, bravo !' : 'Test non réussi.'}\n\n'
          'Ce résultat est enregistré dans votre profil.',
      action: FilledButton(
        onPressed: () => context.go(Routes.tests),
        child: const Text('Retour à mes tests'),
      ),
    );
  }
}
