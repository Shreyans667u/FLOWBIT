-- ============================================================================
-- Flowbit backend schema
-- ----------------------------------------------------------------------------
-- Run this ONCE in your Supabase project: Dashboard → SQL Editor → New query →
-- paste this whole file → Run. That's the entire backend setup.
--
-- What this gives you:
--   - A "projects" table, one row per saved project, owned by a user
--   - Row Level Security (RLS): the database itself enforces "you can only
--     read/write your own projects" — this is what makes it safe to call
--     Supabase directly from the browser with the public "anon" key. The key
--     has no power on its own; these policies are the actual access control.
--   - Two narrow functions for share links, so a stranger with a share link
--     can read exactly one project (and only if it's marked shareable) —
--     without ever being granted general read access to the projects table.
-- ============================================================================

create extension if not exists pgcrypto; -- provides gen_random_uuid()

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'Untitled Project',
  data jsonb not null,
  share_token uuid unique not null default gen_random_uuid(),
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists projects_user_id_idx on public.projects(user_id);

-- Keep updated_at current automatically on every UPDATE
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_projects_updated_at on public.projects;
create trigger trg_projects_updated_at
before update on public.projects
for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- Row Level Security
-- ----------------------------------------------------------------------------
alter table public.projects enable row level security;

-- Owners can select/insert/update/delete only their own rows.
-- Note there is deliberately NO general "public can select" policy here —
-- that would let anyone list every user's projects by querying the table
-- directly. Sharing instead goes through the narrow function below.
create policy "Owners manage their own projects"
on public.projects
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- Sharing: security-definer functions instead of a broad RLS policy
-- ----------------------------------------------------------------------------
-- get_shared_project(token): returns a project ONLY if the caller supplies
-- its exact share_token AND the owner has marked it is_public = true. A
-- share_token is a random UUID (122 bits of randomness) — knowing it is the
-- proof of access, the same trust model as any "unlisted" share link.
create or replace function public.get_shared_project(token uuid)
returns table (id uuid, name text, data jsonb, updated_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select p.id, p.name, p.data, p.updated_at
  from public.projects p
  where p.share_token = token and p.is_public = true;
$$;
grant execute on function public.get_shared_project(uuid) to anon, authenticated;

-- remix_project(token, new_name): copies a shared project into the CALLER'S
-- own account. Requires the caller to be logged in (auth.uid() is not null);
-- Supabase's client sends the caller's identity automatically with every
-- request, so this can't be spoofed from the browser.
create or replace function public.remix_project(token uuid, new_name text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  src record;
  new_id uuid;
begin
  if auth.uid() is null then
    raise exception 'You must be logged in to remix a project';
  end if;

  select * into src from public.projects where share_token = token and is_public = true;
  if src is null then
    raise exception 'Project not found, or it is not shareable';
  end if;

  insert into public.projects (user_id, name, data, is_public)
  values (auth.uid(), coalesce(new_name, src.name || ' (remix)'), src.data, false)
  returning id into new_id;

  return new_id;
end;
$$;
grant execute on function public.remix_project(uuid, text) to authenticated;
