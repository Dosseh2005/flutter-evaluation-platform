import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/annee_scolaire.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../test/test_repository.dart';
import 'stats_repository.dart';

/// Couleur des tests réussis dans les camemberts.
const couleurReussi = Couleurs.reussite;

/// Couleur des tests échoués dans les camemberts.
const couleurEchoue = Couleurs.alerte;

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
    final ordinateur = MediaQuery.sizeOf(context).width >= largeurOrdinateur;
    final seuil = (seuilReussite * 100).round();
    return AdminScaffold(
      titre: 'Statistiques',
      corps: ContenuCentre(
        largeurMax: 1180,
        child: ListView(
          padding: margesPage(context),
          children: [
            if (ordinateur)
              EnTete(
                titre: 'Statistiques',
                description:
                    'Taux de réussite par discipline. Un test est '
                    'réussi à partir de $seuil % de bonnes réponses.',
              ),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: _annee,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Année scolaire',
                    ),
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
                const _Legende(),
                if (!ordinateur)
                  Text(
                    'Réussi à partir de $seuil % de bonnes réponses.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            ChargementFuture<List<StatDiscipline>>(
              future: _stats,
              reessayer: () => setState(_charger),
              builder: (context, stats) {
                final general = CarteCamembert(
                  stat: statGenerale(stats),
                  grand: true,
                );
                final parDiscipline = Panneau(
                  titre: 'Par discipline',
                  child: Column(
                    children: [
                      for (var i = 0; i < stats.length; i++) ...[
                        if (i > 0) const Divider(height: 32),
                        LigneDiscipline(stat: stats[i]),
                      ],
                    ],
                  ),
                );
                return MediaQuery.sizeOf(context).width >= 900
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: general),
                          const SizedBox(width: 24),
                          Expanded(flex: 6, child: parDiscipline),
                        ],
                      )
                    : Column(children: [general, parDiscipline]);
              },
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
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: couleur,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(texte),
      ],
    );
    return Wrap(
      spacing: 20,
      children: [
        element(couleurReussi, 'Réussi'),
        element(couleurEchoue, 'Échoué'),
      ],
    );
  }
}

/// Camembert « réussi / échoué » d'une [stat].
class Camembert extends StatelessWidget {
  /// Crée le camembert de diamètre [taille].
  const Camembert({super.key, required this.stat, required this.taille});

  /// Données affichées.
  final StatDiscipline stat;

  /// Diamètre en pixels.
  final double taille;

  @override
  Widget build(BuildContext context) {
    if (stat.nbTests == 0) {
      return SizedBox(
        width: taille,
        height: taille,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Couleurs.ligne, width: 2),
          ),
        ),
      );
    }
    final avecTitres = taille >= 160;
    final style = TextStyle(
      fontFamily: policeApp,
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: taille >= 200 ? 16 : 13,
    );
    return SizedBox(
      width: taille,
      height: taille,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 0,
          startDegreeOffset: -90,
          sections: [
            if (stat.nbReussis > 0)
              PieChartSectionData(
                value: stat.nbReussis.toDouble(),
                color: couleurReussi,
                radius: taille / 2,
                title: avecTitres ? '${stat.tauxReussite.round()} %' : '',
                titleStyle: style,
              ),
            if (stat.nbEchoues > 0)
              PieChartSectionData(
                value: stat.nbEchoues.toDouble(),
                color: couleurEchoue,
                radius: taille / 2,
                title: avecTitres
                    ? '${(100 - stat.tauxReussite).round()} %'
                    : '',
                titleStyle: style,
              ),
          ],
        ),
      ),
    );
  }
}

/// Panneau du camembert général (tous les étudiants).
class CarteCamembert extends StatelessWidget {
  /// Crée le panneau ; [grand] pour le camembert général.
  const CarteCamembert({super.key, required this.stat, this.grand = false});

  /// Données affichées.
  final StatDiscipline stat;

  /// Affichage plus grand (camembert général).
  final bool grand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panneau(
      titre: stat.discipline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${stat.nbTests} test(s) passé(s)',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          Center(
            child: stat.nbTests == 0
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Text('Aucun test cette année'),
                  )
                : Camembert(
                    stat: stat,
                    taille: !grand
                        ? 160
                        : MediaQuery.sizeOf(context).width < 520
                        ? 200
                        : 240,
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            '${stat.nbReussis} réussi(s), ${stat.nbEchoues} échoué(s)',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Une discipline : petit camembert, nom, taux et nombres.
class LigneDiscipline extends StatelessWidget {
  /// Crée la ligne.
  const LigneDiscipline({super.key, required this.stat});

  /// Données affichées.
  final StatDiscipline stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Téléphone : camembert plus petit, pourcentage à côté du nom.
    final taille = MediaQuery.sizeOf(context).width < 520 ? 64.0 : 96.0;
    final pourcentage = stat.nbTests == 0
        ? null
        : Text(
            '${stat.tauxReussite.round()} %',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: stat.tauxReussite >= seuilReussite * 100
                  ? couleurReussi
                  : couleurEchoue,
              fontFeatures: chiffresAlignes,
            ),
          );
    return Semantics(
      container: true,
      child: Row(
        children: [
          stat.nbTests == 0
              ? SizedBox(width: taille, height: taille)
              : Camembert(stat: stat, taille: taille),
          SizedBox(width: taille < 96 ? 16 : 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stat.discipline,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    ?pourcentage,
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  stat.nbTests == 0
                      ? 'Aucun test cette année'
                      : '${stat.nbTests} test(s) : ${stat.nbReussis} réussi(s), '
                            '${stat.nbEchoues} échoué(s)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Couleurs.texteSecondaire,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
