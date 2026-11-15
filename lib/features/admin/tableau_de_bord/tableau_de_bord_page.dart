import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/annee_scolaire.dart';
import '../../../core/widgets.dart';
import '../../test/test_repository.dart';
import 'resultats_repository.dart';

/// Tableau de bord de l'administrateur (US6) : derniers résultats des
/// candidats, recherche par nom / prénom et filtre par année scolaire.
class TableauDeBordPage extends ConsumerStatefulWidget {
  /// Crée la page.
  const TableauDeBordPage({super.key});

  @override
  ConsumerState<TableauDeBordPage> createState() => _TableauDeBordPageState();
}

class _TableauDeBordPageState extends ConsumerState<TableauDeBordPage> {
  final _recherche = TextEditingController();
  Timer? _attente;
  String? _annee;
  List<String> _annees = anneesAProposer(const []);
  late Future<List<Resultat>> _resultats;

  ResultatsRepository get _repo => ref.read(resultatsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _charger();
    _repo.annees().then((a) {
      if (mounted) setState(() => _annees = anneesAProposer(a));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _attente?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  void _charger() {
    _resultats =
        _repo.derniersResultats(recherche: _recherche.text, annee: _annee);
  }

  /// Relance la recherche 400 ms après la dernière touche tapée (évite
  /// d'interroger le serveur à chaque lettre).
  void _rechercheModifiee(String _) {
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(_charger);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      titre: 'Tableau de bord',
      corps: ContenuCentre(
        largeurMax: 1100,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _recherche,
                      decoration: const InputDecoration(
                        labelText: 'Rechercher un candidat (nom ou prénom)',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: _rechercheModifiee,
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _annee,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Année scolaire'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Toutes les années')),
                        for (final a in _annees)
                          DropdownMenuItem(value: a, child: Text(a)),
                      ],
                      onChanged: (a) => setState(() {
                        _annee = a;
                        _charger();
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ChargementFuture<List<Resultat>>(
                future: _resultats,
                reessayer: () => setState(_charger),
                builder: (context, resultats) => resultats.isEmpty
                    ? const MessageCentre(
                        icone: Icons.search_off,
                        texte: 'Aucun résultat.',
                      )
                    : _TableauResultats(resultats: resultats),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableauResultats extends StatelessWidget {
  const _TableauResultats({required this.resultats});

  final List<Resultat> resultats;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy HH:mm');
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Text(
          '${resultats.length} résultat(s)'
          '${resultats.length == limiteResultats ? ' (les $limiteResultats plus récents)' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Nom')),
              DataColumn(label: Text('Prénom')),
              DataColumn(label: Text('Discipline')),
              DataColumn(label: Text('Score'), numeric: true),
              DataColumn(label: Text('Résultat')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Année')),
            ],
            rows: [
              for (final r in resultats)
                DataRow(cells: [
                  DataCell(Text(r.nom)),
                  DataCell(Text(r.prenom)),
                  DataCell(Text(r.discipline)),
                  DataCell(Text('${r.score}/${r.total}')),
                  DataCell(estReussi(r.score, r.total)
                      ? const Text('Réussi',
                          style: TextStyle(color: Colors.green))
                      : const Text('Échoué')),
                  DataCell(Text(format.format(r.date))),
                  DataCell(Text(r.anneeScolaire)),
                ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
