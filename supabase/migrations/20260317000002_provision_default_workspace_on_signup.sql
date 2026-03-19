-- Provision one default workspace per user on signup.
-- Depends on: handle_new_workspace being idempotent (migration 20260317000001).
-- This migration only inserts into workspaces; on_workspace_created trigger adds the member.

-- Helper: get default workspace id for a user (for app use).
CREATE OR REPLACE FUNCTION public.get_user_default_workspace_id(p_user_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT w.id
  FROM public.workspaces w
  JOIN public.workspace_members wm ON wm.workspace_id = w.id
  WHERE wm.user_id = p_user_id
    AND wm.status = 'active'
    AND coalesce(w.is_default, false) = true
  ORDER BY w.created_at ASC
  LIMIT 1;
$$;

-- Auth trigger: create default workspace for new user if they have no workspace yet.
CREATE OR REPLACE FUNCTION public.provision_default_workspace_for_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.workspace_members wm
    WHERE wm.user_id = NEW.id
      AND wm.status = 'active'
  ) THEN
    RETURN NEW;
  END IF;

  v_name := trim(coalesce(NEW.raw_user_meta_data->>'first_name', ''));
  IF v_name = '' THEN
    v_name := split_part(NEW.email, '@', 1);
  END IF;
  v_name := left(v_name, 60) || ' Workspace';

  INSERT INTO public.workspaces (id, name, slug, created_by, is_active, is_default, created_at, updated_at)
  VALUES (gen_random_uuid(), v_name, 'ws-' || replace(gen_random_uuid()::text, '-', ''), NEW.id, true, true, now(), now());

  RETURN NEW;
END;
$$;

-- Attach trigger to auth.users (run after other auth triggers so invites can run first).
DROP TRIGGER IF EXISTS on_auth_user_created_provision_default_workspace ON auth.users;
CREATE TRIGGER on_auth_user_created_provision_default_workspace
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.provision_default_workspace_for_new_user();

-- One default workspace per user.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_default_workspace_per_user
  ON public.workspaces (created_by)
  WHERE (coalesce(is_default, false) = true);

-- Backfill: create default workspace for users who have no active membership and no default workspace.
INSERT INTO public.workspaces (id, name, slug, created_by, is_active, is_default, created_at, updated_at)
SELECT gen_random_uuid(), left(split_part(u.email, '@', 1), 60) || ' Workspace', 'ws-' || replace(gen_random_uuid()::text, '-', ''), u.id, true, true, now(), now()
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM public.workspace_members wm WHERE wm.user_id = u.id AND wm.status = 'active'
)
AND NOT EXISTS (
  SELECT 1 FROM public.workspaces w WHERE w.created_by = u.id AND coalesce(w.is_default, false) = true
);

-- Backfill relies on handle_new_workspace to add membership. If we inserted workspaces above,
-- the trigger already ran. Fix orphan workspaces (no active members) by re-adding creator.
INSERT INTO public.workspace_members (id, workspace_id, user_id, role, status, joined_at, created_at, updated_at)
SELECT gen_random_uuid(), w.id, w.created_by, 'admin', 'active', now(), now(), now()
FROM public.workspaces w
WHERE NOT EXISTS (
  SELECT 1 FROM public.workspace_members wm
  WHERE wm.workspace_id = w.id AND wm.status = 'active'
)
ON CONFLICT (workspace_id, user_id) DO UPDATE SET
  status = 'active',
  role = 'admin',
  joined_at = coalesce(public.workspace_members.joined_at, now()),
  updated_at = now();
