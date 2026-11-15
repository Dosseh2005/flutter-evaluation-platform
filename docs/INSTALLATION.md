# Installer et lancer le projet

Ce guide explique tout ce qu'il faut installer et configurer **avant** que l'application fonctionne.

Il y a deux situations :

- **Cas A : vous rejoignez l'équipe.** La base Supabase existe déjà : suivez les étapes 1, 2, 4 et 5 (environ 20 minutes).
- **Cas B : vous partez de zéro** (nouvelle base, autre ordinateur pour la démo…) : suivez toutes les étapes, y compris la 3 (environ 40 minutes).

---

## 1. Installer les outils sur l'ordinateur

| Outil | Pourquoi | Où le trouver |
|---|---|---|
| Git | récupérer le code | https://git-scm.com/downloads |
| Flutter (version 3.35 ou plus récente) | compiler et lancer l'application | https://docs.flutter.dev/get-started/install |
| Google Chrome | lancer la version web | https://www.google.com/chrome |
| VS Code + extension « Flutter » | modifier le code | https://code.visualstudio.com |

Vérifier l'installation dans un terminal :

```bash
flutter doctor
```

Les lignes **Flutter** et **Chrome** doivent être cochées. Android Studio n'est nécessaire que pour lancer la version Android.

## 2. Récupérer le code

```bash
git clone https://github.com/Dosseh2005/flutter-evaluation-platform.git
cd flutter-evaluation-platform
flutter pub get
```

`flutter pub get` télécharge les librairies du projet (Supabase, Riverpod, go_router, fl_chart…).

## 3. Créer et préparer la base Supabase (cas B seulement)

Dans le cas A, demandez simplement à l'équipe de vous inviter dans le projet Supabase existant, puis passez à l'étape 4.

1. **Créer le projet** : sur https://supabase.com, cliquez sur *New project*, choisissez un nom, notez le mot de passe de la base et prenez la région *West EU*.
2. **Désactiver la confirmation par email** : *Authentication → Sign In / Providers → Email*, décochez *Confirm email*, puis *Save*.
   Sans ce réglage, un candidat ne peut pas se connecter avant d'avoir cliqué sur un lien reçu par email.
3. **Créer les tables** : *SQL Editor → New query*. Ouvrez le fichier dans VS Code, faites Ctrl+A puis Ctrl+C, collez dans Supabase et cliquez sur **Run**. Le résultat doit être *Success*. Exécutez les fichiers **dans cet ordre** :
   1. `supabase/schema.sql` : tables, sécurité et fonctions (obligatoire) ;
   2. `supabase/migration_002.sql` : compléments pour les questions et les tests (obligatoire) ;
   3. `supabase/donnees_demo.sql` : 15 questions, 8 candidats et des résultats de démo (recommandé pour tester et pour la soutenance).
4. **Créer le compte administrateur** :
   - *Authentication → Users → Add user → Create new user* ;
   - saisissez un email (par exemple `admin@evaluation.fr`) et un mot de passe, puis cochez **Auto Confirm User** ;
   - dans le *SQL Editor*, exécutez la requête suivante en remplaçant l'email si besoin :

   ```sql
   insert into public.profiles (id, nom, prenom, email, role)
   select id, 'Admin', 'Plateforme', email, 'admin'
     from auth.users where email = 'admin@evaluation.fr'
   on conflict (id) do update set role = 'admin';
   ```

   Le résultat doit afficher une ligne avec `admin`.
5. *(Facultatif)* **Vérifier la sécurité** : exécutez `supabase/verif_securite_us4.sql`. Toutes les lignes de l'onglet *Messages* doivent commencer par **OK**.

## 4. Relier l'application à la base : le fichier `env.json`

1. Dans le dossier du projet, copiez `env.example.json` et nommez la copie `env.json`.
2. Dans Supabase, ouvrez *Project Settings → API Keys* et copiez :
   - **Project URL** (`https://xxxx.supabase.co`) ;
   - la clé **Publishable** (`sb_publishable_…`) ou, à défaut, la clé **anon public** (`eyJ…`).
3. Collez-les dans `env.json` :

```json
{
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_ANON_KEY": "la-clé-publique"
}
```

⚠️ **Ne mettez jamais** la clé `service_role` / `secret` dans ce fichier : elle donne tous les droits sur la base. `env.json` n'est **jamais** envoyé sur GitHub (il est listé dans `.gitignore`).

## 5. Lancer l'application

```bash
flutter run -d chrome --dart-define-from-file=env.json
```

L'application s'ouvre dans Chrome sur l'écran de connexion. Si un écran « Configuration Supabase manquante » s'affiche, le fichier `env.json` est absent ou mal rempli : revenez à l'étape 4.

**Comptes pour tester :**

| Rôle | Email | Mot de passe |
|---|---|---|
| Administrateur | celui créé à l'étape 3.4 | celui choisi à l'étape 3.4 |
| Candidats de démo | `lea.bernard@demo.fr`, `ines.fournier@demo.fr`, `tom.girard@demo.fr`… | `Demo1234!` |
| Nouveau candidat | bouton « Créer un compte » dans l'application | celui que vous choisissez |

## 6. Vérifier que tout fonctionne

```bash
flutter analyze   # doit afficher : No issues found!
flutter test      # doit afficher : All tests passed!
```

---

## Publier la version en ligne (GitHub Pages)

L'application est en ligne à l'adresse https://dosseh2005.github.io/flutter-evaluation-platform/ : c'est ce lien qu'on partage (WhatsApp, email…). Il fonctionne sur Android, iPhone et ordinateur, sans rien installer.

Pour republier après une modification du code (dans **Git Bash**) :

```bash
MSYS_NO_PATHCONV=1 flutter build web --release --base-href /flutter-evaluation-platform/ --dart-define-from-file=env.json
cd build/web
touch .nojekyll
git init -b gh-pages && git add -A && git commit -m "Publication"
git push -f https://github.com/Dosseh2005/flutter-evaluation-platform.git gh-pages
```

La nouvelle version est en ligne une à deux minutes plus tard. `MSYS_NO_PATHCONV=1` empêche Git Bash de transformer `/flutter-evaluation-platform/` en chemin Windows.

## Problèmes fréquents

| Ce que vous voyez | Cause | Solution |
|---|---|---|
| « Configuration Supabase manquante » | `env.json` absent, mal nommé ou mal rempli | refaire l'étape 4, puis relancer avec `--dart-define-from-file=env.json` |
| « La base de données n'est pas à jour » | `migration_002.sql` n'a pas été exécuté | l'exécuter dans le SQL Editor (étape 3.3) |
| « Confirmez votre email » après une inscription | la confirmation par email est encore active | étape 3.2 |
| L'admin arrive sur « Mes tests » | la requête de l'étape 3.4 n'a pas été exécutée, ou l'email ne correspond pas | relancer la requête avec le bon email |
| « Email ou mot de passe incorrect » | erreur de saisie, ou compte inexistant | vérifier dans *Authentication → Users* |
| « Ce test ne contient encore aucune question » | aucune question dans cette discipline | exécuter `donnees_demo.sql` ou importer `data/questions_*.json` depuis l'espace admin |
| *Error: query: Too small…* dans le SQL Editor | la zone de texte était vide au moment du *Run* | recoller le fichier puis cliquer sur *Run* |
| `flutter` n'est pas reconnu | Flutter n'est pas installé ou pas dans le PATH | étape 1, puis rouvrir le terminal |
