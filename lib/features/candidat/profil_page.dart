import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/erreurs.dart';
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
        builder: (context, donnees) => ContenuCentre(
          largeurMax: 700,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Informations(profil: donnees.$1),
              const SizedBox(height: 16),
              _FormulaireModifiable(profil: donnees.$1),
              const SizedBox(height: 16),
              _MesScores(scores: donnees.$2),
            ],
          ),
        ),
      ),
    );
  }
}

class _Informations extends StatelessWidget {
  const _Informations({required this.profil});

  final Profil profil;

  @override
  Widget build(BuildContext context) {
    Widget ligne(String libelle, String valeur) => ListTile(
          dense: true,
          title: Text(libelle),
          trailing: Text(valeur, style: Theme.of(context).textTheme.bodyLarge),
        );
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text('Mes informations',
                style: Theme.of(context).textTheme.titleMedium),
          ),
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
  late final TextEditingController _adresse =
      TextEditingController(text: widget.profil.adresse ?? '');
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
      await ref.read(profilRepositoryProvider).mettreAJour(
            adresse: _adresse.text,
            motivation: _motivation!,
          );
      afficherMessage(messenger, 'Profil mis à jour');
    } catch (e) {
      afficherMessage(messenger, messageErreur(e),
          erreur: true, couleurErreur: couleurErreur);
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Informations modifiables',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adresse,
                decoration:
                    const InputDecoration(labelText: 'Adresse postale *'),
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
              FilledButton(
                onPressed: _envoiEnCours ? null : _enregistrer,
                child: Text(_envoiEnCours ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Mes scores',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            if (scores.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text("Vous n'avez encore passé aucun test."),
              ),
            for (final s in scores)
              ListTile(
                leading: Icon(
                  estReussi(s.score, s.total)
                      ? Icons.check_circle
                      : Icons.cancel_outlined,
                  color: estReussi(s.score, s.total) ? Colors.green : null,
                ),
                title: Text(s.discipline),
                subtitle: Text('Passé le ${format.format(s.date)}'),
                trailing: Text(
                  '${s.score} / ${s.total}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
