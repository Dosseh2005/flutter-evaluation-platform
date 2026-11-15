/// Année scolaire d'une [date] : de septembre à août.
///
/// Exemples : 15/11/2026 → « 2026-2027 », 10/03/2027 → « 2026-2027 ».
/// Même règle que la fonction SQL `annee_scolaire()`.
String anneeScolaire(DateTime date) {
  final debut = date.month >= 9 ? date.year : date.year - 1;
  return '$debut-${debut + 1}';
}

/// Liste triée (la plus récente d'abord) des années scolaires à proposer
/// dans un filtre : celles trouvées dans les [donnees] + l'année en cours.
List<String> anneesAProposer(Iterable<String> donnees, {DateTime? maintenant}) {
  final annees = {...donnees, anneeScolaire(maintenant ?? DateTime.now())};
  return annees.toList()..sort((a, b) => b.compareTo(a));
}
