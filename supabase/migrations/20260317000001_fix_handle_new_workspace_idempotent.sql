-- Make workspace-creation trigger idempotent so signup provisioning and backfills
-- do not conflict with the automatic "add creator as admin" insert.
-- Run this migration BEFORE provision_default_workspace_on_signup.

CREATE OR REPLACE FUNCTION public.handle_new_workspace()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.workspace_members (workspace_id, user_id, role, status, joined_at, created_at, updated_at)
  VALUES (NEW.id, NEW.created_by, 'admin', 'active', now(), now(), now())
  ON CONFLICT (workspace_id, user_id)
  DO UPDATE SET
    role = 'admin',
    status = 'active',
    joined_at = COALESCE(public.workspace_members.joined_at, EXCLUDED.joined_at),
    updated_at = now();
  RETURN NEW;
END;
$$;
