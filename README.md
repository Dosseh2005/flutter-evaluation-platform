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

## Fonctionnalités (User Stories)

| US | Qui | Ce qu'on peut faire | Écran |
|---|---|---|---|
| US1 | Candidat | Créer un compte (nom, prénom, email, âge, adresse, motivation, mot de passe) ; erreurs claires si un champ manque ou si le compte existe déjà | `/register` |
| US2 | Candidat | Passer chaque test **une seule fois**, une question à la fois, avec compte à rebours ; à 0 la réponse part automatiquement ; score à la fin | `/tests`, `/test/:id` |
| US3 | Candidat | Voir son profil et ses scores ; modifier **seulement** l'adresse et la motivation | `/profil` |
| US4 | Admin | Se connecter avec un compte pré-existant ; un candidat ne peut pas accéder à l'admin | `/login`, `/admin` |
| US5 | Admin | Ajouter / modifier / supprimer des questions (Radio ou Checkbox, bonnes réponses, temps limite) ; réinitialiser une discipline par fichier JSON | `/admin/questions` |
| US6 | Admin | Derniers résultats, recherche par nom / prénom, filtre par année scolaire | `/admin/tableau-de-bord` |
| US7 | Admin | Camembert de réussite par discipline + camembert général, par année scolaire | `/admin/statistiques` |

## Technologies

| Besoin | Outil |
|---|---|
| Application (Web + Android) | Flutter / Dart |
| Backend : base de données, comptes, logique serveur | Supabase (PostgreSQL, Auth, Row Level Security, fonctions SQL) |
| Gestion de l'état | flutter_riverpod |
| Navigation | go_router |
| Camemberts | fl_chart |
| Import JSON | file_picker |
| Dates | intl |

## Design

Identité « salle d'examen » : encre sur papier, sobre et lisible, pour qu'un candidat reste concentré sur ses questions.

| Élément | Choix |
|---|---|
| Couleurs | encre `#1B2A4A` (titres, boutons), papier `#F6F7F9` (fond), vert `#0F7B6C` (réussi), rouge `#B42318` (échoué, chrono urgent) |
| Police | IBM Plex Sans, intégrée à l'appli (`assets/fonts`, licence SIL OFL) ; chiffres alignés pour le chrono et les scores |
| Élément fort | l'écran du test façon feuille de réponses : réponses A, B, C, D, progression question par question, chrono en grand qui passe en rouge sous 6 secondes |
| Mise en page | connexion en deux colonnes sur ordinateur ; menu latéral pour l'admin ; tout s'adapte au téléphone |

Toutes les couleurs et tailles de texte sont définies à un seul endroit : `lib/core/theme.dart`.

## Structure du dépôt

```
lib/
  main.dart                 démarrage : connexion Supabase + application
  core/                     commun à toute l'appli
    supabase_client.dart    clés (env.json) et raccourci `supabase`
    session.dart            utilisateur connecté + rôle
    router.dart             routes + garde de route selon le rôle
    widgets.dart            squelettes de pages, chargement, messages
    erreurs.dart            erreurs traduites en français
    annee_scolaire.dart     calcul de l'année scolaire (septembre → août)
    disciplines.dart        lecture des disciplines
  features/
    auth/                   US1, US4 : inscription, connexion, validations
    candidat/               US2, US3 : « Mes tests », profil
    test/                   US2 : passage d'un test + chronomètre
    admin/                  US4 : menu admin
      questions/            US5 : formulaire, liste, import JSON
      tableau_de_bord/      US6 : résultats, recherche, filtre
      statistiques/         US7 : camemberts
test/                       un fichier de tests par US
supabase/
  schema.sql                tables, sécurité (RLS), fonctions – à exécuter en 1er
  migration_002.sql         compléments (US2, US5) – à exécuter en 2e
  donnees_demo.sql          questions + candidats + résultats de démo (facultatif)
  verif_securite_us4.sql    vérifie qu'un candidat ne peut rien faire d'admin
data/                       fichiers JSON d'import (5 questions par discipline)
docs/soutenance.md          plan des slides + scénario de démo
```

---

## Installation de la base Supabase (une seule fois, par une personne)

1. Créer un projet gratuit sur https://supabase.com et inviter les coéquipiers (**Organization > Team**).
2. **Authentication > Sign In / Providers > Email** : désactiver *Confirm email* puis **Save** (sinon chaque candidat doit valider un email avant de pouvoir se connecter).
3. **SQL Editor > New query** : coller **tout** `supabase/schema.sql` puis **Run** → *Success*.
4. **SQL Editor > New query** : coller **tout** `supabase/migration_002.sql` puis **Run** → *Success*.
5. **Compte admin (US4)** : **Authentication > Users > Add user > Create new user** (email + mot de passe, cocher *Auto Confirm User*), puis dans le SQL Editor (remplacer l'email) :

   ```sql
   insert into public.profiles (id, nom, prenom, email, role)
   select id, 'Admin', 'Plateforme', email, 'admin'
     from auth.users where email = 'admin@evaluation.fr'
   on conflict (id) do update set role = 'admin';
   ```

6. *(Facultatif, recommandé pour la démo)* coller `supabase/donnees_demo.sql` puis **Run** : ajoute 5 questions par discipline, 8 candidats et leurs résultats sur 2 années scolaires.
7. *(Vérification US4)* coller `supabase/verif_securite_us4.sql` puis **Run** : toutes les lignes de l'onglet *Messages* doivent commencer par **OK**.

### Comptes de démonstration

| Rôle | Email | Mot de passe |
|---|---|---|
| Admin | celui créé à l'étape 5 (ex : `admin@evaluation.fr`) | choisi à l'étape 5 |
| Candidats (si `donnees_demo.sql` exécuté) | `lea.bernard@demo.fr`, `hugo.petit@demo.fr`, `ines.fournier@demo.fr`, `tom.girard@demo.fr`… | `Demo1234!` |

> Les candidats de démo ont déjà passé certains tests : pour tester l'US2 de bout en bout, inscrivez un **nouveau** candidat depuis l'appli.

---

## Lancer l'application (chaque membre)

1. Copier `env.example.json` en `env.json` (ce fichier n'est **jamais** envoyé sur GitHub).
2. Y mettre l'URL et la clé **anon / publishable** du projet (Supabase : **Project Settings > API Keys**). Ne jamais utiliser la clé `service_role` / `secret`.
3. Lancer :

   ```bash
   flutter pub get
   flutter run -d chrome --dart-define-from-file=env.json
   ```

Sans `env.json`, l'appli affiche un écran qui explique quoi faire au lieu de planter.

### Navigation et sécurité de l'interface (`lib/core/router.dart`)

| Route | Accès |
|---|---|
| `/login`, `/register` | non connecté |
| `/tests`, `/test/:id`, `/profil` | candidat connecté |
| `/admin`, `/admin/questions`, `/admin/tableau-de-bord`, `/admin/statistiques` | admin uniquement |

La garde de route (`calculerRedirection`) renvoie chacun vers la bonne page selon son rôle (`profiles.role`). **La vraie sécurité est dans la base** (RLS) : même en appelant l'API directement, un candidat ne peut rien faire d'admin.

---

## Fonctionnement du backend (à connaître pour la soutenance)

Notre backend, c'est **Supabase** : PostgreSQL pour les données, des **fonctions SQL** pour la logique et des **règles RLS** pour la sécurité. Les bonnes réponses ne quittent jamais le serveur.

| US | Où c'est géré |
|---|---|
| US1 – champs obligatoires | validations du formulaire **et** contraintes `check` sur `profiles` |
| US1 – compte unique Nom + Email | contrainte `unique (nom, email)` ; le profil est créé par le trigger `handle_new_user` à partir de `auth.signUp(data: {...})` |
| US2 – un seul passage par test | contrainte `unique (candidat_id, discipline_id)` sur `tentatives` + fonction `commencer_test` |
| US2 – temps limite | le serveur enregistre l'heure d'affichage de chaque question (`question_suivante`) ; une réponse arrivée trop tard est comptée fausse (`repondre`, 3 s de tolérance réseau) |
| US2 – triche | les bonnes réponses ne sont jamais envoyées à l'appli ; la correction se fait dans `repondre` |
| US2 – reprise | si la page est fermée, `question_suivante` renvoie la même question avec le temps **restant** (le chrono ne repart pas de zéro) |
| US3 – modifier adresse + motivation | droit `update` limité à ces 2 colonnes ; RLS : chacun ne voit que son profil |
| US4 – accès admin | colonne `role` + fonction `is_admin()` utilisée par toutes les règles de sécurité |
| US5 – créer / modifier | fonction `enregistrer_question` (question + choix en une seule transaction, contrôles `verifier_question`) |
| US5 – import JSON | fonction `reinitialiser_discipline` : tout est vérifié **avant** de supprimer quoi que ce soit (tout ou rien) |
| US6 – filtre par année | colonne `annee_scolaire` (septembre à août), recherche `ilike` (sans tenir compte des majuscules) |
| US7 – camemberts | fonction `stats_reussite(annee, seuil)` ; un test est réussi à partir de **50 %** (constante `seuilReussite`) |

### Format du fichier JSON d'import (US5)

```json
{
  "questions": [
    {
      "enonce": "Quel mot-clé permet à une classe d'hériter d'une autre classe ?",
      "type": "radio",
      "temps_limite_sec": 30,
      "choix": [
        { "texte": "extends", "correct": true },
        { "texte": "implements", "correct": false }
      ]
    }
  ]
}
```

`type` vaut `radio` (exactement une bonne réponse) ou `checkbox` (une ou plusieurs) ; `temps_limite_sec` est en secondes ; au moins 2 choix. Exemples complets : `data/questions_java.json`, `data/questions_algorithmes.json`, `data/questions_html_css.json`.

---

## Qualité du code

```bash
flutter analyze   # 0 erreur, 0 avertissement (inclut la règle public_member_api_docs)
flutter test      # tests automatiques : un fichier par US dans test/
```

- **Documentation** : chaque classe et fonction publique a un commentaire `///`. La règle `public_member_api_docs` (dans `analysis_options.yaml`) fait échouer `flutter analyze` s'il en manque un.
- **Tests** : les écrans sont testés avec de faux serveurs (aucune connexion nécessaire) : validations, chronomètre qui envoie la réponse à 0, import JSON, recherche, filtres, calcul des taux…
- `dart doc` (génération HTML) plante actuellement à cause d'un bug de l'outil `dartdoc` 9.0.6 fourni avec le SDK (`RangeError` dans `_stripDocImports`), indépendant de notre code. À relancer après une mise à jour de Flutter : `dart doc --output doc/api`.

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
