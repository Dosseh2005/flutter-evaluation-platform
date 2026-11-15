import 'package:flutter/material.dart';

/// Mise en page commune aux écrans de connexion et d'inscription :
/// un formulaire centré, de largeur limitée (lisible sur ordinateur)
/// et défilant (utilisable sur téléphone).
class FormulaireCentre extends StatelessWidget {
  /// Crée la mise en page avec un [titre] et les [enfants] du formulaire.
  const FormulaireCentre({
    super.key,
    required this.titre,
    required this.enfants,
  });

  /// Titre affiché dans la barre du haut.
  final String titre;

  /// Champs et boutons du formulaire, de haut en bas.
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titre)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final enfant in enfants) ...[
                  enfant,
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
