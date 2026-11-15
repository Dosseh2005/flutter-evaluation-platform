import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/erreurs.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../auth/validateurs.dart';
import '../test/test_repository.dart';
import 'profil_repository.dart';

/// Profil du candidat (US3) : informations personnelles (lecture seule),
/// adresse et motivation modifiables, et scores des tests passés.
class ProfilPage extends ConsumerStatefulWidget {
  /// Crée la page « Mon profil ».
  const ProfilPage({super.key});

  @override
  ConsumerState<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends ConsumerState<ProfilPage> {
  late Future<(Profil, List<ScoreTest>)> _donnees;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _charger() {
    final repo = ref.read(profilRepositoryProvider);
    _donnees = (repo.monProfil(), repo.mesScores()).wait;
  }

  @override
  Widget build(BuildContext context) {
    return CandidatScaffold(
      titre: 'Mon profil',
      corps: ChargementFuture<(Profil, List<ScoreTest>)>(
        future: _donnees,
        reessayer: () => setState(_charger),
        builder: (context, donnees) {
          final ordinateur = MediaQuery.sizeOf(context).width >= 900;
          final gauche = [
            _Informations(profil: donnees.$1),
            _FormulaireModifiable(profil: donnees.$1),
          ];
          final droite = _MesScores(scores: donnees.$2);
          return ContenuCentre(
            largeurMax: 1080,
            child: ListView(
              padding: margesPage(context),
              children: [
                EnTete(
                  titre: 'Mon profil',
                  description:
                      '${donnees.$1.prenom} ${donnees.$1.nom}, '
                      'retrouvez vos informations et vos résultats.',
                ),
                if (ordinateur)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: Column(children: gauche)),
                      const SizedBox(width: 24),
                      Expanded(flex: 4, child: droite),
                    ],
                  )
                else ...[
                  ...gauche,
                  droite,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Informations extends StatelessWidget {
  const _Informations({required this.profil});

  final Profil profil;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget ligne(String libelle, String valeur) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              libelle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Couleurs.texteSecondaire,
              ),
            ),
          ),
          Expanded(child: Text(valeur, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
    return Panneau(
      titre: 'Mes informations',
      child: Column(
        children: [
          ligne('Nom', profil.nom),
          ligne('Prénom', profil.prenom),
          ligne('Email', profil.email),
          ligne('Âge', profil.age == null ? '–' : '${profil.age} ans'),
        ],
      ),
    );
  }
}

/// Adresse postale et motivation : les deux seuls champs modifiables.
class _FormulaireModifiable extends ConsumerStatefulWidget {
  const _FormulaireModifiable({required this.profil});

  final Profil profil;

  @override
  ConsumerState<_FormulaireModifiable> createState() =>
      _FormulaireModifiableState();
}

class _FormulaireModifiableState extends ConsumerState<_FormulaireModifiable> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _adresse = TextEditingController(
    text: widget.profil.adresse ?? '',
  );
  late String? _motivation = motivations.contains(widget.profil.motivation)
      ? widget.profil.motivation
      : null;
  bool _envoiEnCours = false;

  @override
  void dispose() {
    _adresse.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final couleurErreur = Theme.of(context).colorScheme.error;
    setState(() => _envoiEnCours = true);
    try {
      await ref
          .read(profilRepositoryProvider)
          .mettreAJour(adresse: _adresse.text, motivation: _motivation!);
      afficherMessage(messenger, 'Profil mis à jour');
    } catch (e) {
      afficherMessage(
        messenger,
        messageErreur(e),
        erreur: true,
        couleurErreur: couleurErreur,
      );
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Panneau(
      titre: 'Informations modifiables',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _adresse,
              decoration: const InputDecoration(labelText: 'Adresse postale *'),
              maxLines: 2,
              validator: (v) => obligatoire(v, champ: "L'adresse"),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _motivation,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Motivation *'),
              items: [
                for (final m in motivations)
                  DropdownMenuItem(value: m, child: Text(m)),
              ],
              onChanged: (v) => setState(() => _motivation = v),
              validator: validerMotivation,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _envoiEnCours ? null : _enregistrer,
                child: Text(_envoiEnCours ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MesScores extends StatelessWidget {
  const _MesScores({required this.scores});

  final List<ScoreTest> scores;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy');
    final theme = Theme.of(context);
    return Panneau(
      titre: 'Mes scores',
      child: scores.isEmpty
          ? Text(
              "Vous n'avez encore passé aucun test. Rendez-vous dans "
              '« Mes tests » pour commencer.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Couleurs.texteSecondaire,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < scores.length; i++) ...[
                  if (i > 0) const Divider(height: 24),
                  Semantics(
                    container: true,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scores[i].discipline,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Passé le ${format.format(scores[i].date)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${scores[i].score} / ${scores[i].total}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontFeatures: chiffresAlignes,
                              ),
                            ),
                            const SizedBox(height: 4),
                            estReussi(scores[i].score, scores[i].total)
                                ? const Pastille(
                                    'Réussi',
                                    ton: TonPastille.reussite,
                                  )
                                : const Pastille(
                                    'Non réussi',
                                    ton: TonPastille.alerte,
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
