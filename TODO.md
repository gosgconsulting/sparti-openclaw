# TODO

Living task list for this repo.

## Done

- **Supabase workspace-per-user tenancy (plan)**  
  - Inspect workspace schema and helpers: done.  
  - Fix `handle_new_workspace` to be idempotent (ON CONFLICT): done (migration 20260317000001).  
  - Add signup provisioning (auth trigger, default workspace, backfill, orphan fix): done (migration 20260317000002).  
  - Fix `get_workspace_slot_info` ambiguous `billing_month`: done (migration 20260317000003).  
  - Invite acceptance: already implemented (`accept_workspace_invitation`).  
  - See `docs/SUPABASE_TENANCY.md` and `supabase/migrations/`.

## Next

- **Tenant-scoped tables and RLS** (in Supabase project): Ensure all bot/account/integration tables have `workspace_id` and RLS using `is_workspace_member(workspace_id, auth.uid())`.  
- **Verification**: Test with two users that workspace isolation and invite flow work (in the app that uses the Supabase project).

## Notes

- Supabase tenancy applies to the **linked Supabase project**, not to this repo’s code (this repo is the OpenClaw Railway template).  
- Plan reference: `.cursor/plans/supabase_workspace-per-user_tenancy_732ae75a.plan.md`.
