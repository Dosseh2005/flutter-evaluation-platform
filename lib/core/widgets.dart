import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'erreurs.dart';
import 'router.dart';
import 'session.dart';

/// Squelette commun des pages candidat : barre du haut avec « Mes tests »,
/// « Mon profil » et la déconnexion.
class CandidatScaffold extends ConsumerWidget {
  /// Crée le squelette avec un [titre] et un [corps].
  const CandidatScaffold({super.key, required this.titre, required this.corps});

  /// Titre de la page.
  final String titre;

  /// Contenu de la page.
  final Widget corps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titre),
        actions: [
          IconButton(
            tooltip: 'Mes tests',
            icon: const Icon(Icons.quiz_outlined),
            onPressed: () => context.go(Routes.tests),
          ),
          IconButton(
            tooltip: 'Mon profil',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go(Routes.profil),
          ),
          BoutonDeconnexion(ref: ref),
        ],
      ),
      body: corps,
    );
  }
}

/// Squelette commun des pages admin : retour au menu + déconnexion.
class AdminScaffold extends ConsumerWidget {
  /// Crée le squelette avec un [titre], un [corps] et des [actions]
  /// supplémentaires dans la barre du haut.
  const AdminScaffold({
    super.key,
    required this.titre,
    required this.corps,
    this.actions = const [],
    this.boutonFlottant,
  });

  /// Titre de la page.
  final String titre;

  /// Contenu de la page.
  final Widget corps;

  /// Boutons ajoutés avant la déconnexion.
  final List<Widget> actions;

  /// Bouton flottant (ex : « Ajouter »).
  final Widget? boutonFlottant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour au menu',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.admin),
        ),
        title: Text(titre),
        actions: [...actions, BoutonDeconnexion(ref: ref)],
      ),
      body: corps,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(texte, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Affiche [message] en bas de l'écran (en rouge si [erreur]).
void afficherMessage(ScaffoldMessengerState messenger, String message,
    {bool erreur = false, Color? couleurErreur}) {
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: erreur ? (couleurErreur ?? Colors.red.shade700) : null,
  ));
}

/// Largeur maximale du contenu sur grand écran, centré.
class ContenuCentre extends StatelessWidget {
  /// Crée le conteneur.
  const ContenuCentre({super.key, required this.child, this.largeurMax = 900});

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
