-- =====================================================================
--  Plateforme d'évaluation – Compléments à schema.sql (Sprints 2 et 3)
--  À exécuter APRÈS schema.sql : Supabase > SQL Editor > New query > Run
--  On peut l'exécuter plusieurs fois sans risque (create or replace).
--
--  Ajoute :
--   - verifier_question       : contrôles d'une question (US5)
--   - enregistrer_question    : créer / modifier une question en une fois (US5)
--   - reinitialiser_discipline: import JSON avec contrôles complets (US5)
--   - commencer_test          : refuse un test sans question (US2)
--   - mes_tests               : liste des tests du candidat (US2)
-- =====================================================================


-- ---------------------------------------------------------------------
-- US5 : contrôles d'une question (format JSON identique au fichier d'import)
--   { "enonce": "...", "type": "radio"|"checkbox", "temps_limite_sec": 30,
--     "choix": [ { "texte": "...", "correct": true }, ... ] }
-- ---------------------------------------------------------------------
create or replace function public.verifier_question(q jsonb, n int)
returns void language plpgsql immutable as $$
declare
  v_nb_choix  int;
  v_nb_bonnes int;
begin
  if coalesce(trim(q->>'enonce'), '') = '' then
    raise exception 'Question % : l''énoncé est vide', n;
  end if;
  if coalesce(q->>'type', '') not in ('radio', 'checkbox') then
    raise exception 'Question % : le type doit être "radio" ou "checkbox"', n;
  end if;
  if coalesce(q->>'temps_limite_sec', '') !~ '^[0-9]+$'
     or (q->>'temps_limite_sec')::int <= 0 then
    raise exception 'Question % : le temps limite doit être un nombre de secondes supérieur à 0', n;
  end if;
  if jsonb_typeof(q->'choix') is distinct from 'array' then
    raise exception 'Question % : la liste "choix" est manquante', n;
  end if;

  select count(*),
         count(*) filter (where coalesce((c->>'correct')::boolean, false))
    into v_nb_choix, v_nb_bonnes
    from jsonb_array_elements(q->'choix') as c;

  if v_nb_choix < 2 then
    raise exception 'Question % : il faut au moins 2 choix', n;
  end if;
  if exists (select 1 from jsonb_array_elements(q->'choix') as c
              where coalesce(trim(c->>'texte'), '') = '') then
    raise exception 'Question % : un choix est vide', n;
  end if;
  if v_nb_bonnes < 1 then
    raise exception 'Question % : il faut au moins une bonne réponse', n;
  end if;
  if q->>'type' = 'radio' and v_nb_bonnes <> 1 then
    raise exception 'Question % : une question "radio" doit avoir exactement une bonne réponse', n;
  end if;
end;
$$;


-- ---------------------------------------------------------------------
-- US5 : créer (p_question_id = null) ou modifier une question avec ses choix.
--   Tout est fait en une seule transaction : soit tout est enregistré, soit rien.
--   Renvoie l'id de la question.
-- ---------------------------------------------------------------------
create or replace function public.enregistrer_question(
  p_question_id   bigint,
  p_discipline_id int,
  p_question      jsonb
) returns bigint language plpgsql security definer set search_path = public as $$
declare
  v_id bigint;
begin
  if not is_admin() then
    raise exception 'Réservé à l''administrateur';
  end if;
  perform verifier_question(p_question, 1);

  if p_question_id is null then
    insert into questions (discipline_id, enonce, type, temps_limite_sec, ordre)
    values (
      p_discipline_id,
      trim(p_question->>'enonce'),
      p_question->>'type',
      (p_question->>'temps_limite_sec')::int,
      coalesce((select max(ordre) from questions where discipline_id = p_discipline_id), 0) + 1
    )
    returning id into v_id;
  else
    update questions
       set enonce           = trim(p_question->>'enonce'),
           type             = p_question->>'type',
           temps_limite_sec = (p_question->>'temps_limite_sec')::int
     where id = p_question_id
    returning id into v_id;
    if v_id is null then
      raise exception 'Question introuvable';
    end if;
    delete from choix where question_id = v_id;
  end if;

  insert into choix (question_id, texte, est_correct)
  select v_id, trim(c->>'texte'), coalesce((c->>'correct')::boolean, false)
    from jsonb_array_elements(p_question->'choix') with ordinality as t(c, i)
   order by i;

  return v_id;
end;
$$;


-- ---------------------------------------------------------------------
-- US5 : import JSON – remplace toutes les questions d'une discipline.
--   Toutes les questions sont vérifiées AVANT de supprimer quoi que ce soit.
-- ---------------------------------------------------------------------
create or replace function public.reinitialiser_discipline(p_discipline_id int, p_questions jsonb)
returns int language plpgsql security definer set search_path = public as $$
declare
  q      jsonb;
  c      jsonb;
  v_qid  bigint;
  v_n    int := 0;
begin
  if not is_admin() then
    raise exception 'Réservé à l''administrateur';
  end if;
  if not exists (select 1 from disciplines where id = p_discipline_id) then
    raise exception 'Discipline introuvable';
  end if;
  if jsonb_typeof(p_questions) is distinct from 'array'
     or jsonb_array_length(p_questions) = 0 then
    raise exception 'Le fichier doit contenir une liste "questions" non vide';
  end if;

  -- 1) Tout vérifier
  for q in select * from jsonb_array_elements(p_questions) loop
    v_n := v_n + 1;
    perform verifier_question(q, v_n);
  end loop;

  -- 2) Tout remplacer
  delete from questions where discipline_id = p_discipline_id;
  v_n := 0;
  for q in select * from jsonb_array_elements(p_questions) loop
    v_n := v_n + 1;
    insert into questions (discipline_id, enonce, type, temps_limite_sec, ordre)
    values (p_discipline_id, trim(q->>'enonce'), q->>'type', (q->>'temps_limite_sec')::int, v_n)
    returning id into v_qid;

    for c in select * from jsonb_array_elements(q->'choix') loop
      insert into choix (question_id, texte, est_correct)
      values (v_qid, trim(c->>'texte'), coalesce((c->>'correct')::boolean, false));
    end loop;
  end loop;

  return v_n;   -- nombre de questions importées
end;
$$;


-- ---------------------------------------------------------------------
-- US2 : démarrer un test – refusé s'il n'y a encore aucune question
--   (sinon le candidat aurait 0/0 et ne pourrait plus jamais le repasser)
-- ---------------------------------------------------------------------
create or replace function public.commencer_test(p_discipline_id int)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  v_id bigint;
begin
  if auth.uid() is null then
    raise exception 'Non connecté';
  end if;
  if exists (select 1 from tentatives
             where candidat_id = auth.uid() and discipline_id = p_discipline_id) then
    raise exception 'Test déjà passé';
  end if;
  if not exists (select 1 from questions where discipline_id = p_discipline_id) then
    raise exception 'Ce test ne contient encore aucune question';
  end if;

  insert into tentatives (candidat_id, discipline_id, total, annee_scolaire)
  values (auth.uid(),
          p_discipline_id,
          (select count(*) from questions where discipline_id = p_discipline_id),
          annee_scolaire(now()))
  returning id into v_id;

  return v_id;
end;
$$;


-- ---------------------------------------------------------------------
-- US2 : les tests du candidat connecté (une ligne par discipline)
--   tentative_id null  -> pas encore commencé
--   termine = false    -> commencé mais pas fini (on peut reprendre)
--   termine = true     -> déjà passé : score / total
-- ---------------------------------------------------------------------
create or replace function public.mes_tests()
returns table (
  discipline_id int,
  discipline    text,
  nb_questions  bigint,
  tentative_id  bigint,
  score         int,
  total         int,
  termine       boolean
) language sql stable security definer set search_path = public as $$
  select d.id,
         d.nom,
         (select count(*) from questions q where q.discipline_id = d.id),
         t.id,
         t.score,
         t.total,
         t.fin is not null
    from disciplines d
    left join tentatives t
           on t.discipline_id = d.id and t.candidat_id = auth.uid()
   where auth.uid() is not null
   order by d.id;
$$;
