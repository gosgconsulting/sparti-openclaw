# Supabase workspace-per-user tenancy

This document describes how tenant (workspace) isolation works in the **linked Supabase project** and how to fix or apply the signup provisioning. The app that uses this tenancy may live in another repo (e.g. Clawdi.ai); this repo (sparti-openclaw) is the OpenClaw Railway template and does not contain Supabase app code.

## Goal

- **1 user = 1 default workspace** (one “instance” per client), created automatically on signup.
- **Teams**: invite members to the same workspace; all data is scoped by `workspace_id` and enforced by RLS.
- **Bots, accounts, integrations**: belong to a workspace; access via `is_workspace_member(workspace_id, auth.uid())`.

## What already exists (reuse)

| Component | Status |
|-----------|--------|
| `public.workspaces` | Exists, has `created_by`, `is_default` |
| `public.workspace_members` | Exists, unique `(workspace_id, user_id)` |
| `public.workspace_invitations` | Exists, invite flow in place |
| `is_workspace_member(workspace_id, user_id)` | Exists, SECURITY DEFINER |
| `is_workspace_admin(workspace_id, user_id)` | Exists, SECURITY DEFINER |
| `check_workspace_member_access(...)` | Exists |
| `accept_workspace_invitation(invitation_id)` | Exists, SECURITY DEFINER — converts pending invite to `workspace_members` row |
| Trigger `on_workspace_created` → `handle_new_workspace()` | **Exists but not idempotent** — plain INSERT into `workspace_members`, causes duplicate key if membership is also inserted elsewhere |

## Why the first migration failed

The signup-provisioning migration did:

1. Insert into `workspaces` (new row).
2. Insert into `workspace_members` (creator as admin).

But **after** the INSERT into `workspaces`, the existing trigger `on_workspace_created` runs `handle_new_workspace()`, which **also** inserts into `workspace_members`. So we had two inserts for the same `(workspace_id, user_id)` — the second (from our code or from backfill) hit the unique constraint and the migration failed.

## Fix (ordered)

### 1. Make `handle_new_workspace` idempotent

The trigger must use `ON CONFLICT (workspace_id, user_id) DO UPDATE` (or `DO NOTHING`) so that:

- Creating a workspace always adds the creator as admin.
- If membership already exists (e.g. from another path), no duplicate key error.

**Migration 1:** `supabase/migrations/YYYYMMDD_fix_handle_new_workspace_idempotent.sql`

### 2. Add signup provisioning (workspace only)

- New auth trigger **only** inserts into `public.workspaces` (name, `created_by`, `is_default = true`).
- The existing `on_workspace_created` trigger then runs and inserts the creator into `workspace_members` (now idempotent).
- Enforce at most one default workspace per user: unique partial index `(created_by)` WHERE `is_default = true`.

**Migration 2:** `supabase/migrations/YYYYMMDD_provision_default_workspace_on_signup.sql`

### 3. Backfill users without any workspace

- For each `auth.users` row that has no active `workspace_members` row, insert one workspace (`created_by = user.id`, `is_default = true`). The (fixed) trigger adds the membership.

## How it should work after the fix

1. **Signup**  
   - User signs up → `auth.users` INSERT.  
   - Auth trigger `provision_default_workspace_for_new_user` runs → INSERT one row into `public.workspaces` (`created_by = new.id`, `is_default = true`).  
   - Trigger `on_workspace_created` runs → `handle_new_workspace` inserts into `workspace_members` (or ON CONFLICT DO UPDATE).  
   - User now has exactly one default workspace and is admin.

2. **Invite**  
   - Admin creates `workspace_invitations` row (existing policies).  
   - Invitee accepts → app or RPC calls `accept_workspace_invitation(invitation_id)` → INSERT into `workspace_members`, UPDATE invitation status.  
   - Team shares the same instance (workspace).

3. **App**  
   - Resolve “current workspace” from session (e.g. default workspace for user).  
   - All tenant-scoped tables use `workspace_id` and RLS with `is_workspace_member(workspace_id, auth.uid())`.

## Migrations in this repo

Migrations are in `supabase/migrations/`. Apply them in order against the Supabase project (Dashboard SQL editor or `supabase db push` if the project is linked). Run **Migration 1** before **Migration 2**.

## References

- Plan: `.cursor/plans/supabase_workspace-per-user_tenancy_732ae75a.plan.md`
- Invitation acceptance: existing `public.accept_workspace_invitation(invitation_id uuid)`.
