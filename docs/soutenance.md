# Préparation de la soutenance

Ce document sert à toute l'équipe : plan des slides, scénario de démo, et fiches pour **expliquer n'importe quelle partie du code** (exigence de la DoD : le formateur peut interroger n'importe quel membre sur n'importe quelle boucle).

---

## 1. Plan des slides (≈ 12 slides, 15 minutes)

| # | Slide | Contenu | Qui |
|---|---|---|---|
| 1 | Titre | Nom du projet, équipe, date | |
| 2 | Contexte et idée | Besoin : évaluer des candidats en Java, Algorithmes, HTML/CSS ; 2 profils (candidat, admin) | |
| 3 | Équipe et rôles | Scrum Master, développeurs, PO = formateur | |
| 4 | Organisation EduScrum | Trello (colonnes), Daily, DoD, DoF, rétros, 3 sprints | |
| 5 | Technologies | Flutter (Web + Android), Supabase, Riverpod, go_router, fl_chart | |
| 6 | Architecture | Schéma : appli Flutter → Supabase (Auth + PostgreSQL + fonctions SQL + RLS) | |
| 7 | Base de données | Tables `profiles`, `disciplines`, `questions`, `choix`, `tentatives`, `reponses_candidat` + contraintes clés | |
| 8 | Sécurité | Bonnes réponses jamais envoyées, correction côté serveur, RLS, 1 seul passage garanti par la base | |
| 9 | Démo candidat | US1, US2, US3 (captures ou démo live) | |
| 10 | Démo admin | US4, US5, US6, US7 | |
| 11 | Qualité | Tests automatiques (un fichier par US), `flutter analyze` à 0, code documenté | |
| 12 | Difficultés et bilan | Ce qui a été dur, ce qu'on a appris, ce qu'on améliorerait | |

**À ajouter pour chaque US terminée** (DoD) : une capture d'écran de l'écran principal.

---

## 2. Scénario de démo (≈ 6 minutes)

Préparer avant : base avec `donnees_demo.sql` exécuté, un onglet Chrome sur l'appli, l'email/mot de passe admin à portée de main.

1. **Inscription (US1)** : `/register` → cliquer *S'inscrire* sans rien remplir → messages d'erreur → remplir avec un nouvel email → arrivée sur *Mes tests*.
2. **Passer un test (US2)** : *Commencer* sur Java → montrer le chrono et la barre de progression → répondre à 2 questions → **laisser le temps s'écouler** sur une question (réponse envoyée automatiquement) → score final.
3. **Un seul passage** : retour à *Mes tests* → « Déjà passé – score X/5 », bouton désactivé.
4. **Profil (US3)** : *Mon profil* → nom/email non modifiables → changer l'adresse et la motivation → *Enregistrer* → les scores sont affichés.
5. **Admin (US4)** : se déconnecter → se connecter en admin → menu admin. (Bonus : se reconnecter en candidat et taper `/admin` dans l'URL → renvoyé vers *Mes tests*.)
6. **Questions (US5)** : onglet Java → ajouter une question Checkbox avec 2 bonnes réponses → montrer qu'une question Radio avec 2 bonnes réponses est refusée → *Réinitialiser via JSON* avec `data/questions_java.json` → confirmation → « 5 questions importées ».
7. **Tableau de bord (US6)** : chercher « lea » → filtre 2025-2026 → filtre 2026-2027 (le candidat inscrit à l'étape 1 apparaît).
8. **Statistiques (US7)** : camembert général + 3 camemberts → changer d'année.

**Plan B** si Internet ne marche pas : enregistrer une vidéo de cette démo à l'avance.

---

## 3. Fiches « expliquer le code »

### Le chronomètre (US2) – `lib/features/test/test_page.dart`, `_lancerChrono`

```dart
_chrono = Timer.periodic(const Duration(seconds: 1), (timer) {
  setState(() => _restant--);      // 1 seconde de moins, l'écran se redessine
  if (_restant <= 0) {
    timer.cancel();                 // on arrête le chrono
    _valider();                     // et on envoie la réponse automatiquement
  }
});
```

- `Timer.periodic` appelle la fonction **toutes les secondes**.
- Le temps de départ vient **du serveur** (`temps_restant_sec`) : si on recharge la page, le chrono ne repart pas de zéro.
- Même si quelqu'un trafique l'appli, le serveur refuse une réponse arrivée trop tard (`repondre` compare l'heure d'affichage et l'heure de réponse).

### Le calcul du score (US2) – `supabase/schema.sql`, fonctions `repondre` et `question_suivante`

- `repondre` compare la liste des choix cochés (triée) avec la liste des bonnes réponses (triée) : `est_correcte = dans_le_temps AND choix_donnés = bonnes_réponses`.
- Quand il n'y a plus de question, `question_suivante` calcule `score = nombre de réponses correctes` et enregistre la date de fin.
- Pour une Checkbox, il faut cocher **exactement** toutes les bonnes réponses (ni plus, ni moins).

### L'import JSON (US5) – `lib/features/admin/questions/`

1. `choisirFichierJsonProvider` ouvre le sélecteur de fichiers et lit le texte.
2. `jsonDecode` transforme le texte en objets Dart.
3. `lireFichierImport` **boucle** sur chaque question : `Question.depuisFichier` puis `verifierQuestion` (au moins 2 choix, au moins 1 bonne réponse, exactement 1 si radio…). À la première erreur, on s'arrête avec le numéro de la question.
4. Confirmation, puis la fonction SQL `reinitialiser_discipline` revérifie tout **avant** de supprimer : si une question est fausse, rien n'est modifié (transaction).

### Les camemberts (US7) – `lib/features/admin/statistiques/`

- `stats_reussite(annee, seuil)` renvoie pour chaque discipline : nombre de tests et nombre de réussis (score / total ≥ 50 %).
- `statGenerale` additionne toutes les disciplines avec `fold` (une boucle qui accumule une somme).
- `PieChart` de fl_chart reçoit 2 sections : réussis (vert) et échoués (rouge), avec le pourcentage en titre.

### La garde de route (US4) – `lib/core/router.dart`, `calculerRedirection`

- Pas connecté → `/login` (sauf `/login` et `/register`).
- Candidat qui va sur `/admin...` → renvoyé vers `/tests`.
- Admin qui va sur une page candidat → renvoyé vers `/admin`.
- Rappel : c'est du confort. **La vraie sécurité est dans la base** (RLS + `is_admin()`).

---

## 4. Questions probables du jury

| Question | Réponse courte |
|---|---|
| Pourquoi Supabase et pas un backend codé ? | Supabase *est* notre backend : PostgreSQL + fonctions SQL pour la logique + RLS pour la sécurité. Ça nous a permis de finir les 7 US avec une sécurité de niveau professionnel. |
| Un candidat peut-il voir les bonnes réponses ? | Non : la table `choix` est réservée à l'admin (RLS) et `question_suivante` n'envoie que l'id et le texte des choix. |
| Peut-on repasser un test en rechargeant la page ? | Non : contrainte `unique (candidat_id, discipline_id)` dans la base. Recharger reprend la même tentative avec le temps restant. |
| Que se passe-t-il si le fichier JSON est faux ? | Il est refusé avec le numéro de la question en erreur, et rien n'est modifié (vérification côté appli **et** côté serveur). |
| Comment avez-vous testé ? | Tests automatiques par US (`flutter test`) avec de faux serveurs + tests manuels de chaque critère d'acceptance + script `verif_securite_us4.sql`. |
| Comment est calculée l'année scolaire ? | De septembre à août : novembre 2026 → « 2026-2027 », mars 2027 → « 2026-2027 ». Même règle en Dart et en SQL. |
