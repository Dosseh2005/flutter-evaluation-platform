# Plateforme d'évaluation – The Flutter Project

Plateforme d'évaluation en ligne : les candidats créent un compte, passent un test unique et chronométré par discipline (Java, Algorithmes, HTML/CSS) et suivent leurs scores sur leur profil. L'administrateur gère les questions (formulaire ou import JSON), consulte les résultats et les taux de réussite en camemberts.

Projet réalisé en groupe de 4 en EduScrum (Daily, DoD, DoF, Rétrospective).
Suivi des tâches : [Tableau Trello – Plateforme d'évaluation EduScrum](https://trello.com/b/E4wkDNXr/the-flutter-project-plateforme-d%C3%A9valuation-eduscrum)

## Équipe

| Membre | Rôle |
|---|---|
| Dosseh APETI | Scrum Master, développeur |
| *(Prénom Nom)* | Développeur |
| *(Prénom Nom)* | Développeur |
| *(Prénom Nom)* | Développeur |

## Technologies

| Besoin | Outil |
|---|---|
| Application (Web + Android) | Flutter / Dart |
| Base de données + comptes | Supabase (PostgreSQL, Auth, Row Level Security) |
| Gestion de l'état | flutter_riverpod |
| Navigation | go_router |
| Camemberts | fl_chart |
| Import JSON | file_picker |
| Dates | intl |

## Structure du dépôt

```
lib/
  core/            thème, router, client Supabase, utilitaires
  features/
    auth/          inscription, connexion (US1, US4)
    candidat/      liste des tests, profil (US3)
    test/          passage d'un test, chronomètre (US2)
    admin/         questions, import JSON, tableau de bord, stats (US5, US6, US7)
  main.dart
supabase/schema.sql       script complet de la base
data/questions_java.json  exemple de fichier d'import
```

---

## Installation (à faire UNE fois par la personne qui crée le projet)

### 1. Créer le projet Flutter dans ce dépôt

```bash
git clone https://github.com/VOTRE-COMPTE/flutter-evaluation-platform.git
cd flutter-evaluation-platform
flutter create --org com.equipe --project-name evaluation_app --platforms web,android .
flutter pub add supabase_flutter flutter_riverpod go_router fl_chart file_picker intl
```

Ajouter cette ligne à la fin du fichier `.gitignore` (généré par Flutter) pour ne jamais publier les clés :

```
env.json
```

Puis :

```bash
git add .
git commit -m "chore: initialisation du projet Flutter"
git push
git checkout -b develop
git push -u origin develop
```

Sur GitHub : **Settings > Branches > Add rule** sur `main` et cocher *Require a pull request before merging*.

### 2. Créer la base Supabase

1. Créer un projet gratuit sur https://supabase.com et inviter les coéquipiers (**Organization > Team**).
2. **Authentication > Sign In / Providers > Email** : désactiver *Confirm email* (sinon chaque candidat doit valider un email avant de pouvoir se connecter).
3. **SQL Editor** : coller tout le contenu de `supabase/schema.sql` puis **Run**.
4. **Compte admin (US4)** : **Authentication > Users > Add user** (email + mot de passe, cocher *Auto Confirm User*), puis dans le SQL Editor :

```sql
insert into public.profiles (id, nom, prenom, email, role)
select id, 'Admin', 'Plateforme', email, 'admin'
  from auth.users where email = 'admin@exemple.fr';
```

---

## Lancer l'application (chaque membre)

1. Copier `env.example.json` en `env.json`.
2. Y mettre l'URL et la clé **anon / publishable** du projet (Supabase : **Project Settings > API**). Ne jamais utiliser la clé `service_role` dans l'appli.
3. Lancer :

```bash
flutter run -d chrome --dart-define-from-file=env.json
```

La connexion à Supabase est faite dans `lib/core/supabase_client.dart` (appelée par `main.dart`). Partout dans l'appli, utiliser le raccourci `supabase` (ex : `supabase.from('profiles')`). Sans `env.json`, l'appli affiche un écran qui explique quoi faire au lieu de planter.

### Navigation (`lib/core/router.dart`)

| Route | Page | Accès |
|---|---|---|
| `/login`, `/register` | connexion, inscription | non connecté |
| `/tests`, `/profil`, `/test/:id` | candidat | candidat connecté |
| `/admin` | administration | admin uniquement |

La garde de route (`calculerRedirection`) renvoie automatiquement chacun vers la bonne page selon son rôle (`profiles.role`). Elle est testée dans `test/widget_test.dart`.

---

## Fonctionnement de la base (à connaître pour la soutenance)

| US | Où c'est géré |
|---|---|
| US1 – compte unique Nom + Email | contrainte `unique (nom, email)` sur `profiles` ; le profil est créé par le trigger `handle_new_user` à partir des données envoyées dans `auth.signUp(data: {...})` |
| US2 – un seul passage par test | contrainte `unique (candidat_id, discipline_id)` sur `tentatives` |
| US2 – temps limite | le serveur enregistre l'heure d'affichage de chaque question ; une réponse arrivée trop tard est comptée fausse |
| US2 – triche | les bonnes réponses ne sont jamais envoyées à l'appli ; la correction se fait dans la fonction `repondre` |
| US3 – modifier adresse + motivation | droit `update` limité à ces 2 colonnes |
| US4 – accès admin | colonne `role` + fonction `is_admin()` utilisée par toutes les règles de sécurité |
| US5 – import JSON | fonction `reinitialiser_discipline` (tout ou rien) |
| US6 – filtre par année | colonne `annee_scolaire` (septembre à août) |
| US7 – camemberts | fonction `stats_reussite(annee)` |

### Appels depuis Flutter (exemples)

```dart
// US2 – démarrer un test
final tentativeId = await supabase.rpc('commencer_test', params: {'p_discipline_id': disciplineId});

// US2 – question suivante (null = test terminé)
final question = await supabase.rpc('question_suivante', params: {'p_tentative_id': tentativeId});

// US2 – envoyer la réponse
await supabase.rpc('repondre', params: {
  'p_tentative_id': tentativeId,
  'p_question_id': question['id'],
  'p_choix_ids': choixSelectionnes, // List<int>
});

// US5 – import JSON
await supabase.rpc('reinitialiser_discipline', params: {
  'p_discipline_id': disciplineId,
  'p_questions': fichierJson['questions'],
});

// US7 – statistiques
final stats = await supabase.rpc('stats_reussite', params: {'p_annee': '2026-2027'});
```

### Format du fichier JSON d'import (US5)

Voir `data/questions_java.json`. `type` vaut `radio` (une seule bonne réponse) ou `checkbox` (plusieurs) ; `temps_limite_sec` est en secondes.

---

## Règles Git

- `main` : version stable pour la démo (protégée, uniquement par Pull Request)
- `develop` : intégration du travail de l'équipe
- Une branche par carte Trello : `feature/US1-inscription`, `feature/US2-passer-test`…
- Messages de commit : `feat(US1): formulaire d'inscription`, `fix(US2): chronomètre`, `docs: README`
- Chaque Pull Request vers `develop` est relue par un coéquipier (le modèle de PR reprend la DoD)

```bash
git checkout develop && git pull
git checkout -b feature/US1-inscription
# ... coder ...
git add . && git commit -m "feat(US1): formulaire d'inscription"
git push -u origin feature/US1-inscription
# puis ouvrir la Pull Request vers develop sur GitHub
```
