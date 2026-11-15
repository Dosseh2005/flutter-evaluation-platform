import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/annee_scolaire.dart';
import '../../../core/theme.dart';
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
    _resultats = _repo.derniersResultats(
      recherche: _recherche.text,
      annee: _annee,
    );
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
    final ordinateur = MediaQuery.sizeOf(context).width >= largeurOrdinateur;
    return AdminScaffold(
      titre: 'Tableau de bord',
      corps: ContenuCentre(
        largeurMax: 1180,
        child: ListView(
          padding: margesPage(context),
          children: [
            if (ordinateur)
              const EnTete(
                titre: 'Tableau de bord',
                description:
                    'Les derniers tests terminés, du plus récent au '
                    'plus ancien.',
              ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 340,
                  child: TextField(
                    controller: _recherche,
                    decoration: const InputDecoration(
                      labelText: 'Nom ou prénom du candidat',
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
                    decoration: const InputDecoration(
                      labelText: 'Année scolaire',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Toutes les années'),
                      ),
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
            const SizedBox(height: 20),
            ChargementFuture<List<Resultat>>(
              future: _resultats,
              reessayer: () => setState(_charger),
              builder: (context, resultats) => resultats.isEmpty
                  ? const Panneau(
                      child: MessageCentre(
                        icone: Icons.search_off,
                        texte:
                            'Aucun résultat pour cette recherche. '
                            "Essayez un autre nom ou une autre année.",
                      ),
                    )
                  : _TableauResultats(resultats: resultats),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tableau des résultats, dans un panneau qui défile horizontalement sur
/// petit écran.
class _TableauResultats extends StatelessWidget {
  const _TableauResultats({required this.resultats});

  final List<Resultat> resultats;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy HH:mm');
    final theme = Theme.of(context);
    final compteur = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        '${resultats.length} résultat(s)'
        '${resultats.length == limiteResultats ? ' (les $limiteResultats plus récents)' : ''}',
        style: theme.textTheme.bodySmall,
      ),
    );

    // Téléphone : une fiche par résultat au lieu d'un tableau coupé.
    if (MediaQuery.sizeOf(context).width < 700) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          compteur,
          Panneau(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < resultats.length; i++) ...[
                  if (i > 0) const Divider(),
                  Semantics(
                    container: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${resultats[i].prenom} ${resultats[i].nom}',
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  resultats[i].discipline,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Text(
                                  format.format(resultats[i].date),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${resultats[i].score}/${resultats[i].total}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontFeatures: chiffresAlignes,
                                ),
                              ),
                              const SizedBox(height: 4),
                              estReussi(resultats[i].score, resultats[i].total)
                                  ? const Pastille(
                                      'Réussi',
                                      ton: TonPastille.reussite,
                                    )
                                  : const Pastille(
                                      'Échoué',
                                      ton: TonPastille.alerte,
                                    ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '${resultats.length} résultat(s)'
            '${resultats.length == limiteResultats ? ' (les $limiteResultats plus récents)' : ''}',
            style: theme.textTheme.bodySmall,
          ),
        ),
        Panneau(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(rayonPanneau),
            child: LayoutBuilder(
              builder: (context, contraintes) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: contraintes.maxWidth),
                  child: DataTable(
                    horizontalMargin: 24,
                    columnSpacing: 28,
                    headingRowHeight: 48,
                    dataRowMinHeight: 56,
                    dataRowMaxHeight: 56,
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
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                r.nom,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(Text(r.prenom)),
                            DataCell(Text(r.discipline)),
                            DataCell(
                              Text(
                                '${r.score}/${r.total}',
                                style: const TextStyle(
                                  fontFeatures: chiffresAlignes,
                                ),
                              ),
                            ),
                            DataCell(
                              estReussi(r.score, r.total)
                                  ? const Pastille(
                                      'Réussi',
                                      ton: TonPastille.reussite,
                                    )
                                  : const Pastille(
                                      'Échoué',
                                      ton: TonPastille.alerte,
                                    ),
                            ),
                            DataCell(
                              Text(
                                format.format(r.date),
                                style: const TextStyle(
                                  color: Couleurs.texteSecondaire,
                                  fontFeatures: chiffresAlignes,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                r.anneeScolaire,
                                style: const TextStyle(
                                  color: Couleurs.texteSecondaire,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
