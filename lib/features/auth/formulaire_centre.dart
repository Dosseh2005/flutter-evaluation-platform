import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Mise en page des écrans de connexion et d'inscription.
///
/// Sur ordinateur : à gauche une colonne « encre » qui présente la
/// plateforme, à droite le formulaire. Sur téléphone : le formulaire seul,
/// sous le logo.
class FormulaireCentre extends StatelessWidget {
  /// Crée la mise en page avec un [titre], une [description] et les
  /// [enfants] du formulaire.
  const FormulaireCentre({
    super.key,
    required this.titre,
    required this.enfants,
    this.description,
  });

  /// Titre du formulaire.
  final String titre;

  /// Phrase sous le titre.
  final String? description;

  /// Champs et boutons du formulaire, de haut en bas.
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    final ordinateur = MediaQuery.sizeOf(context).width >= 900;

    final formulaire = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: ordinateur ? 56 : 20,
          vertical: 40,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!ordinateur) ...[
                const Align(alignment: Alignment.centerLeft, child: Marque()),
                const SizedBox(height: 36),
              ],
              EnTete(titre: titre, description: description),
              for (final enfant in enfants) ...[
                enfant,
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Couleurs.surface,
      body: ordinateur
          ? Row(
              children: [
                const Expanded(flex: 5, child: _Presentation()),
                Expanded(flex: 6, child: formulaire),
              ],
            )
          : formulaire,
    );
  }
}

/// Colonne de présentation : ce que la plateforme permet, en clair.
class _Presentation extends StatelessWidget {
  const _Presentation();

  @override
  Widget build(BuildContext context) {
    const texteClair = Color(0xFFC9D2E3);
    Widget point(IconData icone, String titre, String texte) => Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: Colors.white, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontFamily: policeApp,
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texte,
                  style: const TextStyle(
                    fontFamily: policeApp,
                    color: texteClair,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      color: Couleurs.encre,
      padding: const EdgeInsets.fromLTRB(56, 48, 56, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Marque(clair: true),
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Évaluez vos compétences en développement',
                  style: TextStyle(
                    fontFamily: policeApp,
                    color: Colors.white,
                    fontSize: 36,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Un test par discipline, des questions chronométrées et un '
                  'résultat enregistré dans votre profil.',
                  style: TextStyle(
                    fontFamily: policeApp,
                    color: texteClair,
                    fontSize: 17,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 40),
                point(
                  Icons.code,
                  'Java, Algorithmes, HTML/CSS',
                  'Choisissez la discipline que vous voulez valider.',
                ),
                point(
                  Icons.timer_outlined,
                  'Un temps limite par question',
                  'À la fin du temps, votre réponse est envoyée automatiquement.',
                ),
                point(
                  Icons.verified_outlined,
                  'Un seul passage par test',
                  'Votre score est enregistré et consultable à tout moment.',
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
