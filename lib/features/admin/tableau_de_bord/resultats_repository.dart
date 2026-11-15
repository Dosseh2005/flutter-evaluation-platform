import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';

/// Un résultat de test affiché dans le tableau de bord (US6).
class Resultat {
  /// Crée un résultat.
  const Resultat({
    required this.nom,
    required this.prenom,
    required this.discipline,
    required this.score,
    required this.total,
    required this.date,
    required this.anneeScolaire,
  });

  /// Lit une ligne de `tentatives` avec le profil et la discipline.
  factory Resultat.fromJson(Map<String, dynamic> json) => Resultat(
    nom: (json['profiles'] as Map)['nom'] as String,
    prenom: (json['profiles'] as Map)['prenom'] as String,
    discipline: (json['disciplines'] as Map)['nom'] as String,
    score: json['score'] as int,
    total: json['total'] as int,
    date: DateTime.parse(json['fin'] as String).toLocal(),
    anneeScolaire: json['annee_scolaire'] as String,
  );

  /// Nom du candidat.
  final String nom;

  /// Prénom du candidat.
  final String prenom;

  /// Discipline du test.
  final String discipline;

  /// Bonnes réponses.
  final int score;

  /// Nombre de questions.
  final int total;

  /// Date de fin du test.
  final DateTime date;

  /// Année scolaire (ex : « 2026-2027 »).
  final String anneeScolaire;
}

/// Nombre maximum de résultats chargés à la fois.
const limiteResultats = 100;

/// Nettoie le texte recherché : enlève les caractères qui ont un sens
/// spécial dans les filtres Supabase (virgule, parenthèses, jokers…).
String nettoyerRecherche(String texte) =>
    texte.replaceAll(RegExp(r'[,()*%:."\\]'), ' ').trim();

/// Lecture des résultats de tous les candidats (réservé à l'admin par
/// les règles RLS de la base).
class ResultatsRepository {
  /// Derniers tests terminés, du plus récent au plus ancien.
  ///
  /// [recherche] filtre sur le nom OU le prénom (sans tenir compte des
  /// majuscules) ; [annee] filtre sur l'année scolaire (`null` = toutes).
  Future<List<Resultat>> derniersResultats({
    String recherche = '',
    String? annee,
  }) async {
    var requete = supabase
        .from('tentatives')
        .select(
          'score, total, fin, annee_scolaire, '
          'profiles!inner(nom, prenom), disciplines(nom)',
        )
        .not('fin', 'is', null);

    if (annee != null) requete = requete.eq('annee_scolaire', annee);

    final texte = nettoyerRecherche(recherche);
    if (texte.isNotEmpty) {
      requete = requete.or(
        'nom.ilike.*$texte*,prenom.ilike.*$texte*',
        referencedTable: 'profiles',
      );
    }

    final lignes = await requete
        .order('fin', ascending: false)
        .limit(limiteResultats);
    return lignes.map(Resultat.fromJson).toList();
  }

  /// Années scolaires pour lesquelles il existe au moins un test.
  Future<List<String>> annees() async {
    final lignes = await supabase.from('tentatives').select('annee_scolaire');
    return lignes.map((l) => l['annee_scolaire'] as String).toSet().toList();
  }
}

/// Fournit le [ResultatsRepository].
final resultatsRepositoryProvider = Provider<ResultatsRepository>(
  (ref) => ResultatsRepository(),
);
