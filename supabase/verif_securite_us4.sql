-- =====================================================================
--  US4 – Vérifier qu'un CANDIDAT ne peut pas faire d'action admin,
--  même en appelant l'API Supabase directement (sans passer par l'appli).
--
--  À coller dans : Supabase > SQL Editor > Run (après schema.sql).
--  Prérequis : au moins un compte candidat inscrit via l'appli.
--
--  Le script se fait passer pour ce candidat (comme le ferait l'API),
--  essaie chaque action interdite et affiche OK si elle est refusée.
--  Tout est annulé à la fin (rollback) : la base n'est pas modifiée.
-- =====================================================================
begin;

-- 1. Choisir un candidat et « devenir » lui
select set_config(
  'request.jwt.claims',
  json_build_object('sub', id, 'role', 'authenticated')::text,
  true
) from public.profiles where role = 'candidat' limit 1;
set local role authenticated;

do $$
declare
  nb int;
begin
  if auth.uid() is null then
    raise exception 'Aucun candidat trouvé : inscrivez-en un via l''appli.';
  end if;

  -- 2. Ajouter une question : doit être refusé
  begin
    insert into public.questions (discipline_id, enonce, type, temps_limite_sec)
    values (1, 'Question pirate', 'radio', 30);
    raise notice 'ÉCHEC : le candidat a pu AJOUTER une question';
  exception when insufficient_privilege then
    raise notice 'OK : ajout de question refusé';
  end;

  -- 3. Modifier / supprimer des questions : aucune ligne visible donc 0 touchée
  update public.questions set enonce = 'modifiée';
  get diagnostics nb = row_count;
  raise notice '% : modification de questions (% ligne(s))',
    case when nb = 0 then 'OK' else 'ÉCHEC' end, nb;

  delete from public.questions;
  get diagnostics nb = row_count;
  raise notice '% : suppression de questions (% ligne(s))',
    case when nb = 0 then 'OK' else 'ÉCHEC' end, nb;

  -- 4. Lire les bonnes réponses : rien ne doit être visible
  select count(*) into nb from public.choix;
  raise notice '% : lecture des choix / bonnes réponses (% ligne(s))',
    case when nb = 0 then 'OK' else 'ÉCHEC' end, nb;

  -- 5. Se donner le rôle admin : doit être refusé
  begin
    update public.profiles set role = 'admin' where id = auth.uid();
    raise notice 'ÉCHEC : le candidat a pu se donner le rôle admin';
  exception when insufficient_privilege then
    raise notice 'OK : changement de rôle refusé';
  end;

  -- 6. Voir les profils des autres : seulement le sien
  select count(*) into nb from public.profiles where id <> auth.uid();
  raise notice '% : lecture des autres profils (% ligne(s))',
    case when nb = 0 then 'OK' else 'ÉCHEC' end, nb;

  -- 7. Réinitialiser une discipline (import JSON) : doit être refusé
  begin
    perform public.reinitialiser_discipline(1, '[]'::jsonb);
    raise notice 'ÉCHEC : le candidat a pu réinitialiser une discipline';
  exception when others then
    raise notice 'OK : réinitialisation refusée (%)', sqlerrm;
  end;
end $$;

rollback;
-- Résultat : lire les messages dans l'onglet « Messages » / « Notices ».
-- Toutes les lignes doivent commencer par OK.
