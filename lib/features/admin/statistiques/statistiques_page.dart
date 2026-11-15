import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/annee_scolaire.dart';
import '../../../core/widgets.dart';
import '../../test/test_repository.dart';
import 'stats_repository.dart';

/// Couleur des tests réussis dans les camemberts.
const couleurReussi = Color(0xFF2E7D32);

/// Couleur des tests échoués dans les camemberts.
const couleurEchoue = Color(0xFFC62828);

/// Statistiques de réussite (US7) : un camembert par discipline et un
/// camembert général, pour l'année scolaire choisie.
class StatistiquesPage extends ConsumerStatefulWidget {
  /// Crée la page.
  const StatistiquesPage({super.key});

  @override
  ConsumerState<StatistiquesPage> createState() => _StatistiquesPageState();
}

class _StatistiquesPageState extends ConsumerState<StatistiquesPage> {
  String _annee = anneeScolaire(DateTime.now());
  List<String> _annees = anneesAProposer(const []);
  late Future<List<StatDiscipline>> _stats;

  StatsRepository get _repo => ref.read(statsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _charger();
    _repo.annees().then((a) {
      if (mounted) setState(() => _annees = anneesAProposer(a));
    }, onError: (_) {});
  }

  void _charger() => _stats = _repo.parDiscipline(_annee);

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      titre: 'Statistiques',
      corps: ContenuCentre(
        largeurMax: 1100,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: _annee,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Année scolaire'),
                    items: [
                      for (final a in _annees)
                        DropdownMenuItem(value: a, child: Text(a)),
                    ],
                    onChanged: (a) => setState(() {
                      _annee = a!;
                      _charger();
                    }),
                  ),
                ),
                Text(
                  'Un test est réussi à partir de '
                  '${(seuilReussite * 100).round()} % de bonnes réponses.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const _Legende(),
            const SizedBox(height: 8),
            ChargementFuture<List<StatDiscipline>>(
              future: _stats,
              reessayer: () => setState(_charger),
              builder: (context, stats) => Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  CarteCamembert(stat: statGenerale(stats), grand: true),
                  for (final s in stats) CarteCamembert(stat: s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legende extends StatelessWidget {
  const _Legende();

  @override
  Widget build(BuildContext context) {
    Widget element(Color couleur, String texte) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 14, height: 14, color: couleur),
            const SizedBox(width: 6),
            Text(texte),
          ],
        );
    return Wrap(spacing: 16, children: [
      element(couleurReussi, 'Réussi'),
      element(couleurEchoue, 'Échoué'),
    ]);
  }
}

/// Carte avec le camembert « réussi / échoué » d'une [stat].
class CarteCamembert extends StatelessWidget {
  /// Crée la carte ; [grand] pour le camembert général.
  const CarteCamembert({super.key, required this.stat, this.grand = false});

  /// Données affichées.
  final StatDiscipline stat;

  /// Affichage plus grand (camembert général).
  final bool grand;

  @override
  Widget build(BuildContext context) {
    final taille = grand ? 220.0 : 160.0;
    final theme = Theme.of(context);
    final style = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: grand ? 16 : 13,
    );

    return SizedBox(
      width: grand ? 340 : 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(stat.discipline, style: theme.textTheme.titleMedium),
              Text('${stat.nbTests} test(s) passé(s)',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              SizedBox(
                height: taille,
                width: taille,
                child: stat.nbTests == 0
                    ? const Center(child: Text('Aucun test cette année'))
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 0,
                          sections: [
                            if (stat.nbReussis > 0)
                              PieChartSectionData(
                                value: stat.nbReussis.toDouble(),
                                color: couleurReussi,
                                radius: taille / 2,
                                title: '${stat.tauxReussite.round()} %',
                                titleStyle: style,
                              ),
                            if (stat.nbEchoues > 0)
                              PieChartSectionData(
                                value: stat.nbEchoues.toDouble(),
                                color: couleurEchoue,
                                radius: taille / 2,
                                title: '${(100 - stat.tauxReussite).round()} %',
                                titleStyle: style,
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                '${stat.nbReussis} réussi(s) · ${stat.nbEchoues} échoué(s)',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
