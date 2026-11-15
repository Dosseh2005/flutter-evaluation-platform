import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session.dart';

/// Page provisoire affichée tant qu'une US n'est pas codée.
///
/// [titre] s'affiche dans la barre du haut, [us] indique quelle carte
/// Trello remplacera cette page, et [actions] ajoute des boutons de
/// navigation. Si [deconnexion] est vrai, un bouton de déconnexion apparaît.
class PageAVenir extends ConsumerWidget {
  /// Crée une page provisoire.
  const PageAVenir({
    super.key,
    required this.titre,
    required this.us,
    this.actions = const [],
    this.deconnexion = true,
  });

  /// Titre de la page.
  final String titre;

  /// US qui remplacera cette page (ex : « US2 – Passer un test »).
  final String us;

  /// Boutons affichés sous le texte.
  final List<Widget> actions;

  /// Affiche le bouton de déconnexion dans la barre du haut.
  final bool deconnexion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titre),
        actions: [
          if (deconnexion)
            IconButton(
              tooltip: 'Se déconnecter',
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(sessionProvider).deconnecter(),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, size: 48),
              const SizedBox(height: 12),
              Text('À venir : $us', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}
