-- =====================================================================
--  Plateforme d'évaluation – Base de données Supabase (PostgreSQL)
--  À coller dans : Supabase > SQL Editor > New query > Run
--  Couvre : US1 (inscription), US2 (test), US3 (profil), US4 (admin),
--           US5 (questions + import JSON), US6 (tableau de bord), US7 (stats)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. TABLES
-- ---------------------------------------------------------------------

-- Profil d'un utilisateur (candidat ou admin), lié au compte Supabase Auth
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  nom         text not null,
  prenom      text not null,
  email       text not null,
  age         int  check (age between 15 and 99),
  adresse     text,
  motivation  text check (motivation in ('Poursuite d''études', 'Réorientation', 'Reconversion')),
  role        text not null default 'candidat' check (role in ('candidat', 'admin')),
  created_at  timestamptz not null default now(),
  -- US1 : un compte unique par combinaison Nom + Email
  unique (nom, email),
  -- US1 : pour un candidat, tous les champs sont obligatoires
  check (role = 'admin' or (age is not null and adresse is not null and motivation is not null))
);

-- Disciplines (Java, Algorithmes, HTML/CSS)
create table public.disciplines (
  id   int generated always as identity primary key,
  nom  text not null unique
);

-- Questions (US5) : type radio = 1 bonne réponse, checkbox = plusieurs
create table public.questions (
  id                bigint generated always as identity primary key,
  discipline_id     int  not null references public.disciplines(id) on delete cascade,
  enonce            text not null,
  type              text not null check (type in ('radio', 'checkbox')),
  temps_limite_sec  int  not null check (temps_limite_sec > 0),
  ordre             int  not null default 0,
  created_at        timestamptz not null default now()
);

-- Choix de réponse d'une question
create table public.choix (
  id           bigint generated always as identity primary key,
  question_id  bigint not null references public.questions(id) on delete cascade,
  texte        text not null,
  est_correct  boolean not null default false
);

-- Un passage de test par un candidat (US2)
create table public.tentatives (
  id              bigint generated always as identity primary key,
  candidat_id     uuid not null references public.profiles(id) on delete cascade,
  discipline_id   int  not null references public.disciplines(id),
  score           int  not null default 0,
  total           int  not null default 0,
  debut           timestamptz not null default now(),
  fin             timestamptz,
  annee_scolaire  text not null,               -- ex : '2026-2027' (US6, US7)
  -- US2 : le candidat ne peut passer chaque test qu'une seule fois
  unique (candidat_id, discipline_id)
);

-- Réponse du candidat à chaque question (sert aussi au chronomètre côté serveur)
create table public.reponses_candidat (
  tentative_id  bigint not null references public.tentatives(id) on delete cascade,
  question_id   bigint not null references public.questions(id) on delete cascade,
  choix_ids     bigint[] not null default '{}',
  affichee_a    timestamptz not null default now(),   -- début du chrono
  repondue_a    timestamptz,
  est_correcte  boolean,
  primary key (tentative_id, question_id)
);


-- ---------------------------------------------------------------------
-- 2. FONCTIONS UTILITAIRES
-- ---------------------------------------------------------------------

-- Vrai si l'utilisateur connecté est administrateur
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- Année scolaire d'une date : de septembre à août (ex : 10/11/2026 -> '2026-2027')
create or replace function public.annee_scolaire(d timestamptz default now())
returns text language sql stable as $$
  select case
    when extract(month from d) >= 9
      then extract(year from d)::int || '-' || (extract(year from d)::int + 1)
    else (extract(year from d)::int - 1) || '-' || extract(year from d)::int
  end;
$$;


-- ---------------------------------------------------------------------
-- 3. INSCRIPTION (US1) : création automatique du profil
--    L'appli appelle supabase.auth.signUp(..., data: {nom, prenom, age, adresse, motivation})
--    Si une contrainte échoue (doublon Nom+Email, champ manquant), le compte n'est PAS créé.
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- Les comptes créés à la main dans le dashboard (admin) n'ont pas de 'nom' : on ne fait rien
  if new.raw_user_meta_data ? 'nom' then
    insert into public.profiles (id, nom, prenom, email, age, adresse, motivation)
    values (
      new.id,
      new.raw_user_meta_data->>'nom',
      new.raw_user_meta_data->>'prenom',
      new.email,
      (new.raw_user_meta_data->>'age')::int,
      new.raw_user_meta_data->>'adresse',
      new.raw_user_meta_data->>'motivation'
    );
  end if;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ---------------------------------------------------------------------
-- 4. PASSER UN TEST (US2) – tout est contrôlé côté serveur
--    Flux dans l'appli :
--      1) id = rpc('commencer_test', {p_discipline_id})
--      2) q  = rpc('question_suivante', {p_tentative_id: id})   -> null = test fini
--      3) rpc('repondre', {p_tentative_id, p_question_id, p_choix_ids})
--      4) retour à 2)
--    Les bonnes réponses ne sont JAMAIS envoyées à l'appli.
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

  insert into tentatives (candidat_id, discipline_id, total, annee_scolaire)
  values (auth.uid(),
          p_discipline_id,
          (select count(*) from questions where discipline_id = p_discipline_id),
          annee_scolaire(now()))
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.question_suivante(p_tentative_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_t        tentatives%rowtype;
  v_q        questions%rowtype;
  v_affichee timestamptz;
begin
  select * into v_t from tentatives
   where id = p_tentative_id and candidat_id = auth.uid();
  if not found then
    raise exception 'Tentative introuvable';
  end if;
  if v_t.fin is not null then
    return null;
  end if;

  -- Une question déjà affichée mais sans réponse (ex : page rechargée) : on la renvoie
  -- avec le temps qu'il reste (le chrono ne repart PAS de zéro)
  select q.* into v_q
    from reponses_candidat r join questions q on q.id = r.question_id
   where r.tentative_id = p_tentative_id and r.repondue_a is null;

  if not found then
    -- Sinon, prochaine question pas encore vue
    select q.* into v_q from questions q
     where q.discipline_id = v_t.discipline_id
       and not exists (select 1 from reponses_candidat r
                        where r.tentative_id = p_tentative_id and r.question_id = q.id)
     order by q.ordre, q.id
     limit 1;

    if not found then
      -- Plus de question : on termine le test et on calcule le score
      update tentatives
         set fin = now(),
             score = (select count(*) from reponses_candidat
                       where tentative_id = p_tentative_id and est_correcte)
       where id = p_tentative_id;
      return null;
    end if;

    insert into reponses_candidat (tentative_id, question_id)
    values (p_tentative_id, v_q.id);
  end if;

  select affichee_a into v_affichee from reponses_candidat
   where tentative_id = p_tentative_id and question_id = v_q.id;

  return jsonb_build_object(
    'id',                v_q.id,
    'enonce',            v_q.enonce,
    'type',              v_q.type,
    'numero',            (select count(*) from reponses_candidat where tentative_id = p_tentative_id),
    'total',             v_t.total,
    'temps_restant_sec', greatest(0, v_q.temps_limite_sec
                                     - extract(epoch from now() - v_affichee)::int),
    'choix',             (select jsonb_agg(jsonb_build_object('id', c.id, 'texte', c.texte) order by c.id)
                            from choix c where c.question_id = v_q.id)
  );
end;
$$;

create or replace function public.repondre(p_tentative_id bigint, p_question_id bigint, p_choix_ids bigint[])
returns void language plpgsql security definer set search_path = public as $$
declare
  v_affichee timestamptz;
  v_temps    int;
  v_bonnes   bigint[];
  v_donnees  bigint[];
begin
  select r.affichee_a, q.temps_limite_sec into v_affichee, v_temps
    from reponses_candidat r
    join tentatives t on t.id = r.tentative_id
    join questions  q on q.id = r.question_id
   where r.tentative_id = p_tentative_id
     and r.question_id  = p_question_id
     and t.candidat_id  = auth.uid()
     and r.repondue_a is null;
  if not found then
    raise exception 'Question non disponible';
  end if;

  select coalesce(array_agg(id order by id), '{}') into v_bonnes
    from choix where question_id = p_question_id and est_correct;

  select coalesce(array_agg(distinct x order by x), '{}') into v_donnees
    from unnest(coalesce(p_choix_ids, '{}')) as x;

  update reponses_candidat
     set choix_ids    = v_donnees,
         repondue_a   = now(),
         -- Correct seulement si : dans le temps (3 s de tolérance réseau) ET exactement les bons choix
         est_correcte = (now() <= v_affichee + make_interval(secs => v_temps + 3))
                        and v_donnees = v_bonnes
   where tentative_id = p_tentative_id and question_id = p_question_id;
end;
$$;


-- ---------------------------------------------------------------------
-- 5. IMPORT JSON (US5) : réinitialise une discipline complète
--    Appel : rpc('reinitialiser_discipline', {p_discipline_id: 1, p_questions: json['questions']})
--    Tout se fait en une seule transaction : si une question est invalide, rien n'est modifié.
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

  delete from questions where discipline_id = p_discipline_id;

  for q in select * from jsonb_array_elements(p_questions) loop
    v_n := v_n + 1;
    insert into questions (discipline_id, enonce, type, temps_limite_sec, ordre)
    values (p_discipline_id, q->>'enonce', q->>'type', (q->>'temps_limite_sec')::int, v_n)
    returning id into v_qid;

    for c in select * from jsonb_array_elements(q->'choix') loop
      insert into choix (question_id, texte, est_correct)
      values (v_qid, c->>'texte', coalesce((c->>'correct')::boolean, false));
    end loop;

    if not exists (select 1 from choix where question_id = v_qid and est_correct) then
      raise exception 'La question % n''a aucune bonne réponse', v_n;
    end if;
  end loop;

  return v_n;   -- nombre de questions importées
end;
$$;


-- ---------------------------------------------------------------------
-- 6. STATISTIQUES (US7) : taux de réussite par discipline pour une année scolaire
--    Un test est « réussi » si score / total >= p_seuil (0.5 = 50 %, à valider en équipe)
--    Camembert général : additionner nb_reussis et nb_tests de toutes les lignes.
-- ---------------------------------------------------------------------
create or replace function public.stats_reussite(p_annee text, p_seuil numeric default 0.5)
returns table (discipline text, nb_tests bigint, nb_reussis bigint)
language sql stable security definer set search_path = public as $$
  select d.nom,
         count(t.id),
         count(t.id) filter (where t.total > 0 and t.score::numeric / t.total >= p_seuil)
    from disciplines d
    left join tentatives t
           on t.discipline_id = d.id
          and t.annee_scolaire = p_annee
          and t.fin is not null
   where is_admin()
   group by d.id, d.nom
   order by d.id;
$$;


-- ---------------------------------------------------------------------
-- 7. SÉCURITÉ : Row Level Security (qui a le droit de lire / écrire quoi)
-- ---------------------------------------------------------------------
alter table public.profiles          enable row level security;
alter table public.disciplines       enable row level security;
alter table public.questions         enable row level security;
alter table public.choix             enable row level security;
alter table public.tentatives        enable row level security;
alter table public.reponses_candidat enable row level security;

-- Profils : chacun voit le sien, l'admin voit tout (US3, US6)
create policy "profils_lecture" on public.profiles
  for select using (id = auth.uid() or public.is_admin());

-- US3 : le candidat modifie SON profil, et seulement adresse + motivation
create policy "profils_modification" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.profiles from anon, authenticated;
grant  update (adresse, motivation) on public.profiles to authenticated;

-- Disciplines : lisibles par tout utilisateur connecté
create policy "disciplines_lecture" on public.disciplines
  for select to authenticated using (true);

-- Questions et choix : accès direct réservé à l'admin (US5).
-- Les candidats passent par question_suivante(), qui cache les bonnes réponses.
create policy "questions_admin" on public.questions
  for all using (public.is_admin()) with check (public.is_admin());
create policy "choix_admin" on public.choix
  for all using (public.is_admin()) with check (public.is_admin());

-- Tentatives : le candidat voit les siennes, l'admin voit tout.
-- Aucune écriture directe : uniquement via les fonctions ci-dessus.
create policy "tentatives_lecture" on public.tentatives
  for select using (candidat_id = auth.uid() or public.is_admin());

create policy "reponses_lecture" on public.reponses_candidat
  for select using (
    public.is_admin()
    or exists (select 1 from public.tentatives t
                where t.id = tentative_id and t.candidat_id = auth.uid())
  );


-- ---------------------------------------------------------------------
-- 8. DONNÉES DE DÉPART
-- ---------------------------------------------------------------------
insert into public.disciplines (nom) values ('Java'), ('Algorithmes'), ('HTML/CSS');

-- COMPTE ADMIN (US4) – à faire APRÈS avoir créé l'utilisateur dans
-- Authentication > Users > Add user (email + mot de passe, cocher "Auto Confirm User").
-- Remplacer l'email puis exécuter :
--
-- insert into public.profiles (id, nom, prenom, email, role)
-- select id, 'Admin', 'Plateforme', email, 'admin'
--   from auth.users where email = 'admin@exemple.fr';
