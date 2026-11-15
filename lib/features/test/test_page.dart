import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/erreurs.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
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
      final test = tests.firstWhere(
        (t) => t.disciplineId == widget.disciplineId,
      );
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
        setState(
          () => _erreur =
              "Ce test n'a pas encore été commencé. "
              'Utilisez le bouton « Commencer » depuis « Mes tests ».',
        );
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
          toolbarHeight: 64,
          titleSpacing: 20,
          title: Row(
            children: [
              const Marque(compacte: true),
              const SizedBox(width: 14),
              Text(_discipline.isEmpty ? 'Test' : 'Test $_discipline'),
            ],
          ),
        ),
        body: corps,
      ),
    );
  }
}

/// Écran d'une question, présenté comme une feuille de réponses.
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
    final derniere = question.numero >= question.total;

    return ContenuCentre(
      largeurMax: 760,
      child: ListView(
        padding: margesPage(context),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Question ${question.numero}/${question.total}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Couleurs.texteSecondaire,
                  ),
                ),
              ),
              _Chrono(restant: restant),
            ],
          ),
          const SizedBox(height: 12),
          _Progression(numero: question.numero, total: question.total),
          const SizedBox(height: 36),
          Text(question.enonce, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            question.plusieursReponses
                ? 'Plusieurs réponses possibles : cochez toutes les bonnes.'
                : 'Une seule réponse.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Couleurs.texteSecondaire,
            ),
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < question.choix.length; i++)
            _LigneReponse(
              lettre: String.fromCharCode(65 + i),
              texte: question.choix[i].texte,
              cochee: selection.contains(question.choix[i].id),
              plusieurs: question.plusieursReponses,
              actif: !envoiEnCours,
              onTap: () => choisir(
                question.choix[i].id,
                !selection.contains(question.choix[i].id),
              ),
            ),
          const SizedBox(height: 20),
          // Sur téléphone : bouton en pleine largeur, facile à toucher.
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: MediaQuery.sizeOf(context).width < 600
                  ? FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    )
                  : null,
              onPressed: envoiEnCours || selection.isEmpty ? null : valider,
              child: Text(
                envoiEnCours
                    ? 'Envoi…'
                    : derniere
                    ? 'Valider et terminer'
                    : 'Valider',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compte à rebours en grands chiffres ; passe en rouge sous 6 secondes.
class _Chrono extends StatelessWidget {
  const _Chrono({required this.restant});

  final int restant;

  @override
  Widget build(BuildContext context) {
    final urgent = restant <= 5;
    final couleur = urgent ? Couleurs.alerte : Couleurs.encre;
    final minutes = restant ~/ 60;
    final secondes = (restant % 60).toString().padLeft(2, '0');
    return Semantics(
      label: 'Temps restant : $restant secondes',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: urgent ? Couleurs.alerteFond : Couleurs.surface,
          border: Border.all(color: urgent ? Couleurs.alerte : Couleurs.ligne),
          borderRadius: BorderRadius.circular(rayonPetit),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 20, color: couleur),
            const SizedBox(width: 8),
            Text(
              '$minutes:$secondes',
              style: TextStyle(
                fontFamily: policeApp,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: couleur,
                fontFeatures: chiffresAlignes,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre de progression en segments : un segment par question.
class _Progression extends StatelessWidget {
  const _Progression({required this.numero, required this.total});

  final int numero;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Question $numero sur $total',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 1; i <= total; i++) ...[
            if (i > 1) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: i < numero
                      ? Couleurs.encre
                      : i == numero
                      ? Couleurs.encreClaire.withValues(alpha: 0.55)
                      : Couleurs.ligne,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Une réponse proposée, avec sa lettre (A, B, C…) comme sur une feuille
/// de réponses. Annoncée comme bouton radio ou case à cocher.
class _LigneReponse extends StatelessWidget {
  const _LigneReponse({
    required this.lettre,
    required this.texte,
    required this.cochee,
    required this.plusieurs,
    required this.actif,
    required this.onTap,
  });

  final String lettre;
  final String texte;
  final bool cochee;
  final bool plusieurs;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final forme = plusieurs
        ? BorderRadius.circular(6)
        : BorderRadius.circular(999);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        checked: cochee,
        inMutuallyExclusiveGroup: !plusieurs,
        enabled: actif,
        label: texte,
        excludeSemantics: true,
        onTap: actif ? onTap : null,
        child: Material(
          color: cochee ? Couleurs.selection : Couleurs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rayonPetit),
            side: BorderSide(
              color: cochee ? Couleurs.encre : Couleurs.ligne,
              width: cochee ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(rayonPetit),
            onTap: actif ? onTap : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: cochee ? 15 : 16,
                vertical: cochee ? 13 : 14,
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cochee ? Couleurs.encre : Couleurs.surface,
                      border: Border.all(
                        color: cochee ? Couleurs.encre : Couleurs.ligne,
                      ),
                      borderRadius: forme,
                    ),
                    child: cochee && plusieurs
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : Text(
                            lettre,
                            style: TextStyle(
                              fontFamily: policeApp,
                              fontWeight: FontWeight.w600,
                              color: cochee
                                  ? Colors.white
                                  : Couleurs.texteSecondaire,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      texte,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Écran de fin : score, verdict, et retour à la liste.
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
    final theme = Theme.of(context);
    final reussi = estReussi(score, total);
    final pourcentage = total == 0 ? 0 : (score * 100 / total).round();
    return ContenuCentre(
      largeurMax: 560,
      child: ListView(
        padding: margesPage(context),
        children: [
          Panneau(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Test $discipline terminé',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Votre score',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Couleurs.texteSecondaire,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text(
                      '$score / $total',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontFeatures: chiffresAlignes,
                      ),
                    ),
                    Text(
                      '$pourcentage %',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Couleurs.texteSecondaire,
                      ),
                    ),
                    Pastille(
                      reussi ? 'Réussi' : 'Non réussi',
                      ton: reussi ? TonPastille.reussite : TonPastille.alerte,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Ce résultat est enregistré dans votre profil. Un test est '
                  'réussi à partir de ${(seuilReussite * 100).round()} % de '
                  'bonnes réponses.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Couleurs.texteSecondaire,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => context.go(Routes.tests),
                  child: const Text('Retour à mes tests'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
