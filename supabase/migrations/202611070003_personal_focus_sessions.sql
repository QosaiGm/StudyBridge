-- Recoverable, private focus sessions for individual users.
create table if not exists public.focus_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid,
  duration_seconds integer not null check (duration_seconds between 60 and 86400),
  elapsed_seconds integer not null default 0 check (elapsed_seconds >= 0 and elapsed_seconds <= duration_seconds),
  status text not null default 'running' check (status in ('running','paused','completed','cancelled')),
  started_at timestamptz not null default now(),
  segment_started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (subject_id, user_id) references public.subjects(id, user_id) on delete set null (subject_id),
  check ((status = 'running' and segment_started_at is not null and ended_at is null)
      or (status = 'paused' and segment_started_at is null and ended_at is null)
      or (status in ('completed','cancelled') and segment_started_at is null and ended_at is not null))
);
create index if not exists focus_sessions_user_started_idx on public.focus_sessions(user_id, started_at desc);
create unique index if not exists focus_sessions_one_open_per_user_idx on public.focus_sessions(user_id) where status in ('running','paused');

drop trigger if exists focus_sessions_updated_at on public.focus_sessions;
create trigger focus_sessions_updated_at before update on public.focus_sessions for each row execute function public.set_updated_at();
alter table public.focus_sessions enable row level security;
drop policy if exists focus_sessions_select_own on public.focus_sessions;
drop policy if exists focus_sessions_insert_own on public.focus_sessions;
drop policy if exists focus_sessions_update_own on public.focus_sessions;
drop policy if exists focus_sessions_delete_own on public.focus_sessions;
create policy focus_sessions_select_own on public.focus_sessions for select to authenticated using ((select auth.uid()) = user_id);
create policy focus_sessions_insert_own on public.focus_sessions for insert to authenticated with check ((select auth.uid()) = user_id);
create policy focus_sessions_update_own on public.focus_sessions for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy focus_sessions_delete_own on public.focus_sessions for delete to authenticated using ((select auth.uid()) = user_id);
