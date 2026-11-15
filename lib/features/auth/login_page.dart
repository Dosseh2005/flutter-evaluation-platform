import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import 'auth_repository.dart';
import 'formulaire_centre.dart';
import 'validateurs.dart';

/// Écran de connexion commun aux candidats et à l'administrateur
/// (US1, US4). Après connexion, le router envoie le candidat sur /tests
/// et l'administrateur sur /admin, selon `profiles.role`.
class LoginPage extends ConsumerStatefulWidget {
  /// Crée l'écran de connexion.
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _envoiEnCours = false;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  /// Vérifie le formulaire puis connecte l'utilisateur.
  Future<void> _connecter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _envoiEnCours = true);
    // Lus AVANT l'appel réseau (le context peut changer après un await).
    final messenger = ScaffoldMessenger.of(context);
    final couleurErreur = Theme.of(context).colorScheme.error;
    try {
      await ref
          .read(authRepositoryProvider)
          .connecter(email: _email.text, motDePasse: _motDePasse.text);
      // Pas de context.go ici : le router redirige seul selon le rôle.
    } on ErreurAuth catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: couleurErreur),
      );
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: FormulaireCentre(
        titre: 'Connexion',
        description: "Accédez à vos tests ou à l'espace d'administration.",
        enfants: [
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: validerEmail,
          ),
          TextFormField(
            controller: _motDePasse,
            decoration: const InputDecoration(labelText: 'Mot de passe'),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            validator: (v) => (v == null || v.isEmpty)
                ? 'Le mot de passe est obligatoire'
                : null,
            onFieldSubmitted: (_) => _connecter(),
          ),
          FilledButton(
            onPressed: _envoiEnCours ? null : _connecter,
            child: _envoiEnCours
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Se connecter'),
          ),
          TextButton(
            onPressed: () => context.go(Routes.register),
            child: const Text('Pas encore de compte ? Créer un compte'),
          ),
        ],
      ),
    );
  }
}
