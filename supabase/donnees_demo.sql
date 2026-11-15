-- =====================================================================
--  Données de démonstration (à exécuter APRÈS schema.sql et migration_002.sql)
--  Supabase > SQL Editor > New query > Run
--
--  Ajoute :
--   - 5 questions par discipline (contenu de data/*.json)
--   - 8 candidats de démo (mot de passe pour tous : Demo1234!)
--   - leurs résultats sur 2 années scolaires (2025-2026 et 2026-2027)
--  pour tester le tableau de bord (US6) et les statistiques (US7).
--
--  On peut le relancer : les questions sont remplacées, les candidats et
--  résultats déjà présents ne sont pas recréés.
-- =====================================================================

-- 1. QUESTIONS --------------------------------------------------------
create or replace function pg_temp.importer(p_discipline text, p_questions jsonb)
returns void language plpgsql as $$
declare
  v_did int;
  q     jsonb;
  c     jsonb;
  v_qid bigint;
  v_n   int := 0;
begin
  select id into v_did from public.disciplines where nom = p_discipline;
  delete from public.questions where discipline_id = v_did;
  for q in select * from jsonb_array_elements(p_questions) loop
    v_n := v_n + 1;
    perform public.verifier_question(q, v_n);
    insert into public.questions (discipline_id, enonce, type, temps_limite_sec, ordre)
    values (v_did, q->>'enonce', q->>'type', (q->>'temps_limite_sec')::int, v_n)
    returning id into v_qid;
    for c in select * from jsonb_array_elements(q->'choix') loop
      insert into public.choix (question_id, texte, est_correct)
      values (v_qid, c->>'texte', (c->>'correct')::boolean);
    end loop;
  end loop;
end;
$$;

select pg_temp.importer('Java', $q$[{"enonce": "Quel mot-clé permet à une classe d'hériter d'une autre classe ?", "type": "radio", "temps_limite_sec": 30, "choix": [{"texte": "extends", "correct": true}, {"texte": "implements", "correct": false}, {"texte": "inherits", "correct": false}, {"texte": "super", "correct": false}]}, {"enonce": "Parmi ces types, lesquels sont des types primitifs en Java ?", "type": "checkbox", "temps_limite_sec": 45, "choix": [{"texte": "int", "correct": true}, {"texte": "boolean", "correct": true}, {"texte": "String", "correct": false}, {"texte": "double", "correct": true}]}, {"enonce": "Qu'affiche System.out.println(10 / 4); ?", "type": "radio", "temps_limite_sec": 30, "choix": [{"texte": "2", "correct": true}, {"texte": "2.5", "correct": false}, {"texte": "2.0", "correct": false}, {"texte": "3", "correct": false}]}, {"enonce": "Quelle méthode est le point d'entrée d'un programme Java ?", "type": "radio", "temps_limite_sec": 30, "choix": [{"texte": "public static void main(String[] args)", "correct": true}, {"texte": "public void start()", "correct": false}, {"texte": "static int main()", "correct": false}, {"texte": "public static void run(String args)", "correct": false}]}, {"enonce": "Quelles affirmations sur les interfaces Java sont vraies ?", "type": "checkbox", "temps_limite_sec": 60, "choix": [{"texte": "Une classe peut implémenter plusieurs interfaces", "correct": true}, {"texte": "Une interface peut contenir des méthodes default (depuis Java 8)", "correct": true}, {"texte": "Une interface peut avoir un constructeur", "correct": false}, {"texte": "On peut créer un objet directement avec new NomInterface()", "correct": false}]}]$q$::jsonb);
select pg_temp.importer('Algorithmes', $q$[{"enonce": "Quelle est la complexité de la recherche dichotomique dans un tableau trié de n éléments ?", "type": "radio", "temps_limite_sec": 30, "choix": [{"texte": "O(log n)", "correct": true}, {"texte": "O(n)", "correct": false}, {"texte": "O(n log n)", "correct": false}, {"texte": "O(1)", "correct": false}]}, {"enonce": "Combien de fois la boucle « pour i de 1 à 10 par pas de 2 » s'exécute-t-elle ?", "type": "radio", "temps_limite_sec": 30, "choix": [{"texte": "5", "correct": true}, {"texte": "10", "correct": false}, {"texte": "4", "correct": false}, {"texte": "6", "correct": false}]}, {"enonce": "Parmi ces structures de données, lesquelles suivent le principe « premier entré, premier sorti » (FIFO) ?", "type": "checkbox", "temps_limite_sec": 40, "choix": [{"texte": "File (queue)", "correct": true}, {"texte": "Pile (stack)", "correct": false}, {"texte": "File d'attente d'impression", "correct": true}, {"texte": "Arbre binaire", "correct": false}]}, {"enonce": "Que renvoie une fonction récursive factorielle(n) pour n = 4 ?", "type": "radio", "temps_limite_sec": 30, "choix": [{"texte": "24", "correct": true}, {"texte": "16", "correct": false}, {"texte": "10", "correct": false}, {"texte": "4", "correct": false}]}, {"enonce": "Parmi ces algorithmes de tri, lesquels ont une complexité moyenne en O(n log n) ?", "type": "checkbox", "temps_limite_sec": 45, "choix": [{"texte": "Tri fusion", "correct": true}, {"texte": "Tri rapide", "correct": true}, {"texte": "Tri à bulles", "correct": false}, {"texte": "Tri par insertion", "correct": false}]}]$q$::jsonb);
select pg_temp.importer('HTML/CSS', $q$[{"enonce": "Quelle balise HTML crée un lien hypertexte ?", "type": "radio", "temps_limite_sec": 20, "choix": [{"texte": "<a>", "correct": true}, {"texte": "<link>", "correct": false}, {"texte": "<href>", "correct": false}, {"texte": "<url>", "correct": false}]}, {"enonce": "Quelle propriété CSS change la couleur du texte ?", "type": "radio", "temps_limite_sec": 20, "choix": [{"texte": "color", "correct": true}, {"texte": "font-color", "correct": false}, {"texte": "text-color", "correct": false}, {"texte": "background-color", "correct": false}]}, {"enonce": "Parmi ces balises, lesquelles sont des balises sémantiques HTML5 ?", "type": "checkbox", "temps_limite_sec": 40, "choix": [{"texte": "<header>", "correct": true}, {"texte": "<article>", "correct": true}, {"texte": "<div>", "correct": false}, {"texte": "<nav>", "correct": true}]}, {"enonce": "Quel sélecteur CSS cible un élément ayant l'id « menu » ?", "type": "radio", "temps_limite_sec": 25, "choix": [{"texte": "#menu", "correct": true}, {"texte": ".menu", "correct": false}, {"texte": "menu", "correct": false}, {"texte": "*menu", "correct": false}]}, {"enonce": "Quelles valeurs de la propriété « display » permettent de créer une mise en page flexible ou en grille ?", "type": "checkbox", "temps_limite_sec": 40, "choix": [{"texte": "flex", "correct": true}, {"texte": "grid", "correct": true}, {"texte": "block", "correct": false}, {"texte": "inline", "correct": false}]}]$q$::jsonb);


-- 2. CANDIDATS DE DÉMO -------------------------------------------------
--  Créés directement dans auth.users (comme une inscription) : le trigger
--  handle_new_user crée automatiquement leur ligne dans profiles.
create or replace function pg_temp.candidat(
  p_email text, p_nom text, p_prenom text, p_age int, p_adresse text, p_motivation text
) returns uuid language plpgsql as $$
declare
  v_id uuid;
begin
  select id into v_id from auth.users where email = p_email;
  if v_id is not null then
    return v_id;
  end if;
  v_id := gen_random_uuid();
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
    p_email, extensions.crypt('Demo1234!', extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('nom', p_nom, 'prenom', p_prenom, 'age', p_age,
                       'adresse', p_adresse, 'motivation', p_motivation),
    now(), now(), '', '', '', ''
  );
  insert into auth.identities (provider_id, user_id, identity_data, provider,
                               last_sign_in_at, created_at, updated_at)
  values (v_id::text, v_id,
          jsonb_build_object('sub', v_id::text, 'email', p_email, 'email_verified', true),
          'email', now(), now(), now());
  return v_id;
end;
$$;

-- 3. RÉSULTATS ---------------------------------------------------------
--  (email, nom, prénom, âge, adresse, motivation, discipline, score sur 5, date de fin)
with demo(email, nom, prenom, age, adresse, motivation, discipline, score, fin) as (
  values
  -- Année 2025-2026
  ('lea.bernard@demo.fr',   'Bernard',  'Léa',    19, '3 rue Victor Hugo, Lyon',           'Poursuite d''études', 'Java',        4, timestamptz '2025-10-14 10:20'),
  ('lea.bernard@demo.fr',   'Bernard',  'Léa',    19, '3 rue Victor Hugo, Lyon',           'Poursuite d''études', 'Algorithmes', 3, timestamptz '2025-10-15 14:05'),
  ('hugo.petit@demo.fr',    'Petit',    'Hugo',   27, '12 avenue Jean Jaurès, Lille',      'Reconversion',        'Java',        2, timestamptz '2025-12-02 09:40'),
  ('hugo.petit@demo.fr',    'Petit',    'Hugo',   27, '12 avenue Jean Jaurès, Lille',      'Reconversion',        'HTML/CSS',    5, timestamptz '2025-12-03 11:15'),
  ('chloe.moreau@demo.fr',  'Moreau',   'Chloé',  22, '8 place Bellecour, Lyon',           'Réorientation',       'Algorithmes', 1, timestamptz '2026-02-18 16:30'),
  ('chloe.moreau@demo.fr',  'Moreau',   'Chloé',  22, '8 place Bellecour, Lyon',           'Réorientation',       'HTML/CSS',    3, timestamptz '2026-02-19 10:00'),
  ('nathan.roux@demo.fr',   'Roux',     'Nathan', 31, '45 rue Nationale, Tours',           'Reconversion',        'Java',        5, timestamptz '2026-05-06 13:45'),
  -- Année 2026-2027
  ('ines.fournier@demo.fr', 'Fournier', 'Inès',   18, '2 rue de la Paix, Nantes',          'Poursuite d''études', 'Java',        3, timestamptz '2026-09-22 10:10'),
  ('ines.fournier@demo.fr', 'Fournier', 'Inès',   18, '2 rue de la Paix, Nantes',          'Poursuite d''études', 'Algorithmes', 4, timestamptz '2026-09-23 15:20'),
  ('ines.fournier@demo.fr', 'Fournier', 'Inès',   18, '2 rue de la Paix, Nantes',          'Poursuite d''études', 'HTML/CSS',    5, timestamptz '2026-09-24 09:05'),
  ('tom.girard@demo.fr',    'Girard',   'Tom',    24, '17 boulevard Gambetta, Nice',       'Réorientation',       'Java',        1, timestamptz '2026-10-08 11:50'),
  ('tom.girard@demo.fr',    'Girard',   'Tom',    24, '17 boulevard Gambetta, Nice',       'Réorientation',       'HTML/CSS',    2, timestamptz '2026-10-09 14:35'),
  ('sarah.lambert@demo.fr', 'Lambert',  'Sarah',  35, '9 rue du Port, Marseille',          'Reconversion',        'Algorithmes', 5, timestamptz '2026-10-27 10:25'),
  ('sarah.lambert@demo.fr', 'Lambert',  'Sarah',  35, '9 rue du Port, Marseille',          'Reconversion',        'Java',        4, timestamptz '2026-10-28 16:40'),
  ('yanis.mercier@demo.fr', 'Mercier',  'Yanis',  20, '30 rue Sainte-Catherine, Bordeaux', 'Poursuite d''études', 'HTML/CSS',    2, timestamptz '2026-11-12 09:30'),
  ('yanis.mercier@demo.fr', 'Mercier',  'Yanis',  20, '30 rue Sainte-Catherine, Bordeaux', 'Poursuite d''études', 'Algorithmes', 2, timestamptz '2026-11-13 13:15')
)
insert into public.tentatives (candidat_id, discipline_id, score, total, debut, fin, annee_scolaire)
select pg_temp.candidat(d.email, d.nom, d.prenom, d.age, d.adresse, d.motivation),
       di.id, d.score, 5, d.fin - interval '5 minutes', d.fin, public.annee_scolaire(d.fin)
  from demo d
  join public.disciplines di on di.nom = d.discipline
on conflict (candidat_id, discipline_id) do nothing;

-- Vérification : nombre de tests par année scolaire
select annee_scolaire, count(*) as nb_tests
  from public.tentatives group by annee_scolaire order by annee_scolaire;
