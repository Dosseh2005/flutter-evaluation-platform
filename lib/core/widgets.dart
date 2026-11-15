import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'erreurs.dart';
import 'router.dart';
import 'session.dart';
import 'theme.dart';

/// Largeur à partir de laquelle on affiche la mise en page « ordinateur »
/// (menu latéral admin, connexion en deux colonnes).
const largeurOrdinateur = 1100.0;

/// Logo de l'application : un carré « encre » et le nom.
class Marque extends StatelessWidget {
  /// Crée le logo ; [clair] pour l'afficher sur fond encre.
  const Marque({super.key, this.clair = false, this.compacte = false});

  /// Texte blanc (sur fond foncé).
  final bool clair;

  /// N'affiche que le carré (menu latéral étroit).
  final bool compacte;

  @override
  Widget build(BuildContext context) {
    final carre = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: clair ? Colors.white : Couleurs.encre,
        borderRadius: BorderRadius.circular(rayonPetit),
      ),
      child: Icon(
        Icons.fact_check_outlined,
        size: 19,
        color: clair ? Couleurs.encre : Colors.white,
      ),
    );
    if (compacte) return carre;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        carre,
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            "Plateforme d'évaluation",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: policeApp,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: clair ? Colors.white : Couleurs.encre,
            ),
          ),
        ),
      ],
    );
  }
}

/// Titre de page (annoncé comme titre par les lecteurs d'écran) avec un
/// texte d'aide facultatif et des actions alignées à droite.
class EnTete extends StatelessWidget {
  /// Crée l'en-tête.
  const EnTete({
    super.key,
    required this.titre,
    this.description,
    this.actions = const [],
  });

  /// Titre principal de la page.
  final String titre;

  /// Phrase d'explication sous le titre.
  final String? description;

  /// Boutons à droite du titre.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 16,
        runSpacing: 16,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(titre, style: theme.textTheme.headlineMedium),
                ),
                if (description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    description!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Couleurs.texteSecondaire,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

/// Type d'information affichée par une [Pastille].
enum TonPastille {
  /// Réussite (vert).
  reussite,

  /// Échec (rouge).
  alerte,

  /// Information neutre (encre).
  neutre,
}

/// Petite étiquette de statut : « Réussi », « Échoué », « En cours »…
class Pastille extends StatelessWidget {
  /// Crée une pastille.
  const Pastille(this.texte, {super.key, this.ton = TonPastille.neutre});

  /// Texte affiché.
  final String texte;

  /// Couleur selon le sens.
  final TonPastille ton;

  @override
  Widget build(BuildContext context) {
    final (fond, encre) = switch (ton) {
      TonPastille.reussite => (Couleurs.reussiteFond, Couleurs.reussite),
      TonPastille.alerte => (Couleurs.alerteFond, Couleurs.alerte),
      TonPastille.neutre => (Couleurs.selection, Couleurs.encre),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontFamily: policeApp,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: encre,
        ),
      ),
    );
  }
}

/// Panneau blanc bordé (sans ombre), avec un titre de section facultatif.
class Panneau extends StatelessWidget {
  /// Crée un panneau.
  const Panneau({
    super.key,
    required this.child,
    this.titre,
    this.padding = const EdgeInsets.all(20),
  });

  /// Contenu.
  final Widget child;

  /// Titre de la section.
  final String? titre;

  /// Marges intérieures.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Couleurs.surface,
        border: Border.all(color: Couleurs.ligne),
        borderRadius: BorderRadius.circular(rayonPanneau),
      ),
      padding: padding,
      child: titre == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    titre!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 16),
                child,
              ],
            ),
    );
  }
}

/// Squelette des pages candidat : logo, navigation « Mes tests » /
/// « Mon profil » et déconnexion.
class CandidatScaffold extends ConsumerWidget {
  /// Crée le squelette avec un [titre] (annoncé, mais affiché par la page
  /// elle-même) et un [corps].
  const CandidatScaffold({super.key, required this.titre, required this.corps});

  /// Titre de la page (sert à surligner l'onglet actif).
  final String titre;

  /// Contenu de la page.
  final Widget corps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etroit = MediaQuery.sizeOf(context).width < 600;
    Widget lien(String libelle, IconData icone, String route) {
      final actif = libelle == titre;
      final style = TextButton.styleFrom(
        foregroundColor: actif ? Couleurs.encre : Couleurs.texteSecondaire,
        backgroundColor: actif ? Couleurs.selection : null,
      );
      return etroit
          ? IconButton(
              tooltip: libelle,
              icon: Icon(icone),
              color: actif ? Couleurs.encre : Couleurs.texteSecondaire,
              onPressed: () => context.go(route),
            )
          : TextButton.icon(
              style: style,
              onPressed: () => context.go(route),
              icon: Icon(icone, size: 20),
              label: Text(libelle),
            );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 20,
        title: Marque(compacte: MediaQuery.sizeOf(context).width < 900),
        actions: [
          lien('Mes tests', Icons.assignment_outlined, Routes.tests),
          const SizedBox(width: 4),
          lien('Mon profil', Icons.person_outline, Routes.profil),
          const SizedBox(width: 8),
          BoutonDeconnexion(ref: ref),
          const SizedBox(width: 12),
        ],
      ),
      body: corps,
    );
  }
}

/// Sections de l'espace administrateur (menu latéral).
enum SectionAdmin {
  /// Accueil admin.
  accueil('Accueil', Icons.space_dashboard_outlined, Routes.admin),

  /// Gestion des questions (US5).
  questions('Questions', Icons.quiz_outlined, Routes.adminQuestions),

  /// Tableau de bord des résultats (US6).
  tableauDeBord(
    'Tableau de bord',
    Icons.table_rows_outlined,
    Routes.adminTableauDeBord,
  ),

  /// Statistiques (US7).
  statistiques(
    'Statistiques',
    Icons.pie_chart_outline,
    Routes.adminStatistiques,
  );

  const SectionAdmin(this.libelle, this.icone, this.route);

  /// Nom affiché.
  final String libelle;

  /// Icône du menu.
  final IconData icone;

  /// Route go_router.
  final String route;
}

/// Squelette des pages admin : menu latéral « encre » sur ordinateur,
/// barre du haut avec retour au menu sur petit écran.
class AdminScaffold extends ConsumerWidget {
  /// Crée le squelette.
  const AdminScaffold({
    super.key,
    required this.titre,
    required this.corps,
    this.section,
    this.actions = const [],
    this.boutonFlottant,
  });

  /// Titre de la page.
  final String titre;

  /// Contenu de la page.
  final Widget corps;

  /// Section active dans le menu (`null` = déduite du titre).
  final SectionAdmin? section;

  /// Boutons ajoutés avant la déconnexion (petit écran).
  final List<Widget> actions;

  /// Bouton flottant (ex : « Ajouter »).
  final Widget? boutonFlottant;

  SectionAdmin get _section =>
      section ??
      SectionAdmin.values.firstWhere(
        (s) => s.libelle == titre,
        orElse: () => SectionAdmin.accueil,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordinateur = MediaQuery.sizeOf(context).width >= largeurOrdinateur;

    if (!ordinateur) {
      return Scaffold(
        appBar: AppBar(
          leading: _section == SectionAdmin.accueil
              ? null
              : IconButton(
                  tooltip: 'Retour au menu',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go(Routes.admin),
                ),
          title: Text(titre),
          actions: [
            ...actions,
            BoutonDeconnexion(ref: ref),
          ],
        ),
        body: corps,
        floatingActionButton: boutonFlottant,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 256,
            selectedIndex: _section.index,
            onDestinationSelected: (i) =>
                context.go(SectionAdmin.values[i].route),
            leading: const SizedBox(
              width: 256,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 20, 32),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Marque(clair: true),
                ),
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFAEB8CC),
                    ),
                    onPressed: () => ref.read(sessionProvider).deconnecter(),
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Se déconnecter'),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final s in SectionAdmin.values)
                NavigationRailDestination(
                  icon: Icon(s.icone),
                  label: Text(s.libelle),
                ),
            ],
          ),
          Expanded(child: corps),
        ],
      ),
      floatingActionButton: boutonFlottant,
    );
  }
}

/// Bouton de déconnexion (le router renvoie ensuite vers /login).
class BoutonDeconnexion extends StatelessWidget {
  /// Crée le bouton.
  const BoutonDeconnexion({super.key, required this.ref});

  /// Accès aux providers.
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Se déconnecter',
      icon: const Icon(Icons.logout),
      onPressed: () => ref.read(sessionProvider).deconnecter(),
    );
  }
}

/// Affiche le résultat d'un [Future] : roue de chargement, message
/// d'erreur avec bouton « Réessayer », ou le contenu construit par
/// [builder] quand les données sont arrivées.
class ChargementFuture<T> extends StatelessWidget {
  /// Crée l'afficheur pour [future].
  const ChargementFuture({
    super.key,
    required this.future,
    required this.builder,
    required this.reessayer,
  });

  /// Données en cours de chargement.
  final Future<T> future;

  /// Construit la page une fois les données reçues.
  final Widget Function(BuildContext context, T donnees) builder;

  /// Relance le chargement après une erreur.
  final VoidCallback reessayer;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MessageCentre(
            icone: Icons.error_outline,
            texte: messageErreur(snapshot.error!),
            action: OutlinedButton(
              onPressed: reessayer,
              child: const Text('Réessayer'),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}

/// Message centré avec une icône (liste vide, erreur…).
class MessageCentre extends StatelessWidget {
  /// Crée le message.
  const MessageCentre({
    super.key,
    required this.icone,
    required this.texte,
    this.action,
  });

  /// Icône affichée au-dessus du texte.
  final IconData icone;

  /// Texte du message.
  final String texte;

  /// Bouton facultatif sous le texte.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 40, color: Couleurs.texteSecondaire),
              const SizedBox(height: 14),
              Text(
                texte,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Affiche [message] en bas de l'écran (en rouge si [erreur]).
void afficherMessage(
  ScaffoldMessengerState messenger,
  String message, {
  bool erreur = false,
  Color? couleurErreur,
}) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: erreur ? (couleurErreur ?? Couleurs.alerte) : null,
    ),
  );
}

/// Contenu centré de largeur limitée, avec les marges de page.
class ContenuCentre extends StatelessWidget {
  /// Crée le conteneur.
  const ContenuCentre({super.key, required this.child, this.largeurMax = 960});

  /// Contenu.
  final Widget child;

  /// Largeur maximale en pixels.
  final double largeurMax;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largeurMax),
        child: child,
      ),
    );
  }
}

/// Marges de page standard (plus larges sur ordinateur).
EdgeInsets margesPage(BuildContext context) {
  final large = MediaQuery.sizeOf(context).width >= 700;
  return EdgeInsets.symmetric(
    horizontal: large ? 40 : 16,
    vertical: large ? 36 : 20,
  );
}
