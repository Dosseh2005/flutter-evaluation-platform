/// Fonctions de validation des formulaires d'inscription et de connexion.
///
/// Chaque fonction renvoie `null` si la valeur est correcte, sinon le
/// message d'erreur à afficher sous le champ (utilisable directement dans
/// `TextFormField(validator: ...)`).
library;

/// Choix possibles pour la motivation (identiques à la contrainte SQL
/// de la colonne `profiles.motivation`).
const motivations = ["Poursuite d'études", 'Réorientation', 'Reconversion'];

/// Âge minimum et maximum acceptés (identiques à la contrainte SQL).
const ageMin = 15;
const ageMax = 99;

/// Longueur minimale du mot de passe.
const motDePasseMin = 8;

final _regexEmail = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

/// Champ obligatoire : refuse une valeur vide ou faite uniquement d'espaces.
String? obligatoire(String? valeur, {String champ = 'Ce champ'}) {
  if (valeur == null || valeur.trim().isEmpty) return '$champ est obligatoire';
  return null;
}

/// Email obligatoire et au bon format (ex : prenom.nom@exemple.fr).
String? validerEmail(String? valeur) {
  final vide = obligatoire(valeur, champ: "L'email");
  if (vide != null) return vide;
  if (!_regexEmail.hasMatch(valeur!.trim())) return 'Email invalide';
  return null;
}

/// Âge obligatoire : un nombre entier entre [ageMin] et [ageMax].
String? validerAge(String? valeur) {
  final vide = obligatoire(valeur, champ: "L'âge");
  if (vide != null) return vide;
  final age = int.tryParse(valeur!.trim());
  if (age == null) return "L'âge doit être un nombre entier";
  if (age < ageMin || age > ageMax) {
    return "L'âge doit être compris entre $ageMin et $ageMax ans";
  }
  return null;
}

/// Mot de passe obligatoire d'au moins [motDePasseMin] caractères.
String? validerMotDePasse(String? valeur) {
  if (valeur == null || valeur.isEmpty) return 'Le mot de passe est obligatoire';
  if (valeur.length < motDePasseMin) {
    return 'Au moins $motDePasseMin caractères';
  }
  return null;
}

/// Vérifie que la confirmation est identique au [motDePasse] saisi.
String? validerConfirmation(String? valeur, String motDePasse) {
  if (valeur == null || valeur.isEmpty) return 'Confirmez le mot de passe';
  if (valeur != motDePasse) return 'Les mots de passe ne correspondent pas';
  return null;
}

/// Motivation obligatoire et faisant partie de [motivations].
String? validerMotivation(String? valeur) {
  if (valeur == null || !motivations.contains(valeur)) {
    return 'Choisissez une motivation';
  }
  return null;
}
