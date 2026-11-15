import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import 'auth_repository.dart';
import 'formulaire_centre.dart';
import 'validateurs.dart';

/// Écran d'inscription d'un candidat (US1).
///
/// Tous les champs sont obligatoires. Une erreur s'affiche sous chaque
/// champ manquant ou incorrect, et les erreurs du serveur (email déjà
/// utilisé, doublon Nom + Email) s'affichent dans une SnackBar.
class RegisterPage extends ConsumerStatefulWidget {
  /// Crée l'écran d'inscription.
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _email = TextEditingController();
  final _age = TextEditingController();
  final _adresse = TextEditingController();
  final _motDePasse = TextEditingController();
  final _confirmation = TextEditingController();
  String? _motivation;
  bool _envoiEnCours = false;

  @override
  void dispose() {
    for (final c in [
      _nom,
      _prenom,
      _email,
      _age,
      _adresse,
      _motDePasse,
      _confirmation,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Vérifie le formulaire puis crée le compte dans Supabase.
  Future<void> _inscrire() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _envoiEnCours = true);
    // Lus AVANT l'appel réseau : après un await, le context peut ne plus
    // être valide (l'écran a pu être fermé).
    final messenger = ScaffoldMessenger.of(context);
    final couleurErreur = Theme.of(context).colorScheme.error;
    try {
      final resultat = await ref.read(authRepositoryProvider).inscrire(
            nom: _nom.text,
            prenom: _prenom.text,
            email: _email.text,
            motDePasse: _motDePasse.text,
            age: int.parse(_age.text.trim()),
            adresse: _adresse.text,
            motivation: _motivation!,
          );
      if (resultat == ResultatInscription.confirmationEmail && mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text(
            'Compte créé ! Confirmez votre email puis connectez-vous.',
          ),
        ));
        context.go(Routes.login);
      }
      // Si le candidat est connecté, le router l'envoie seul vers /tests.
    } on ErreurAuth catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: couleurErreur,
      ));
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: FormulaireCentre(
        titre: 'Inscription',
        enfants: [
          Text(
            'Créez votre compte pour accéder aux évaluations.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextFormField(
            controller: _nom,
            decoration: const InputDecoration(labelText: 'Nom *'),
            textCapitalization: TextCapitalization.words,
            validator: (v) => obligatoire(v, champ: 'Le nom'),
          ),
          TextFormField(
            controller: _prenom,
            decoration: const InputDecoration(labelText: 'Prénom *'),
            textCapitalization: TextCapitalization.words,
            validator: (v) => obligatoire(v, champ: 'Le prénom'),
          ),
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email *'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: validerEmail,
          ),
          TextFormField(
            controller: _age,
            decoration: const InputDecoration(labelText: 'Âge *'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: validerAge,
          ),
          TextFormField(
            controller: _adresse,
            decoration: const InputDecoration(labelText: 'Adresse postale *'),
            maxLines: 2,
            validator: (v) => obligatoire(v, champ: "L'adresse"),
          ),
          DropdownButtonFormField<String>(
            initialValue: _motivation,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Motivation *'),
            items: [
              for (final m in motivations)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: (v) => setState(() => _motivation = v),
            validator: validerMotivation,
          ),
          TextFormField(
            controller: _motDePasse,
            decoration: const InputDecoration(
              labelText: 'Mot de passe *',
              helperText: 'Au moins $motDePasseMin caractères',
            ),
            obscureText: true,
            validator: validerMotDePasse,
          ),
          TextFormField(
            controller: _confirmation,
            decoration:
                const InputDecoration(labelText: 'Confirmer le mot de passe *'),
            obscureText: true,
            validator: (v) => validerConfirmation(v, _motDePasse.text),
            onFieldSubmitted: (_) => _inscrire(),
          ),
          FilledButton(
            onPressed: _envoiEnCours ? null : _inscrire,
            child: _envoiEnCours
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("S'inscrire"),
          ),
          TextButton(
            onPressed: () => context.go(Routes.login),
            child: const Text("J'ai déjà un compte – me connecter"),
          ),
        ],
      ),
    );
  }
}
