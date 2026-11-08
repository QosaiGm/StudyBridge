-- StudyBridge complete Supabase schema
-- Run this entire script in Supabase SQL Editor. It is safe to rerun and does not delete data.
-- Tables are private by default through explicit owner-only RLS policies.

-- gen_random_uuid() is available in Supabase PostgreSQL; no extension installation is needed.

-- Shared updated_at trigger function.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Profiles: one private profile per Supabase Auth user.
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_length check (char_length(display_name) <= 80)
);

alter table public.profiles enable row level security;
drop policy if exists "Users can read their own profile" on public.profiles;
drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can read their own profile"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy "Users can update their own profile"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Private academic subjects.
create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 120),
  description text not null default '',
  color text not null default 'lavender',
  semester text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);
create index if not exists subjects_user_name_idx on public.subjects(user_id, name);

-- Lectures must reference a subject owned by the same user.
create table if not exists public.lectures (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid not null,
  title text not null check (char_length(trim(title)) between 1 and 180),
  description text not null default '',
  lecture_date date,
  is_completed boolean not null default false,
  notes text not null default '',
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes between 1 and 1440),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (subject_id, user_id) references public.subjects(id, user_id) on delete cascade
);
create index if not exists lectures_user_date_idx on public.lectures(user_id, lecture_date);
create index if not exists lectures_subject_idx on public.lectures(subject_id);

-- Tasks can optionally belong to one of the user's subjects.
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid,
  title text not null check (char_length(trim(title)) between 1 and 180),
  description text not null default '',
  due_at timestamptz,
  priority text not null default 'medium' check (priority in ('low','medium','high')),
  is_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (subject_id, user_id) references public.subjects(id, user_id) on delete set null (subject_id)
);
create index if not exists tasks_user_due_idx on public.tasks(user_id, due_at) where not is_completed;

-- Private planner sessions.
create table if not exists public.planner_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid,
  title text not null check (char_length(trim(title)) between 1 and 180),
  description text not null default '',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  is_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  foreign key (subject_id, user_id) references public.subjects(id, user_id) on delete set null (subject_id)
);
create index if not exists planner_user_start_idx on public.planner_sessions(user_id, starts_at);

-- Personal focus sessions persist timestamps so the timer can recover after suspension.
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
  check (
    (status = 'running' and segment_started_at is not null and ended_at is null)
    or (status = 'paused' and segment_started_at is null and ended_at is null)
    or (status in ('completed','cancelled') and segment_started_at is null and ended_at is not null)
  )
);
create index if not exists focus_sessions_user_started_idx on public.focus_sessions(user_id, started_at desc);
create unique index if not exists focus_sessions_one_open_per_user_idx
  on public.focus_sessions(user_id) where status in ('running','paused');

-- Install timestamp triggers, RLS, and owner-only CRUD policies for academic and focus tables.
do $$
declare
  table_name text;
  action_name text;
begin
  foreach table_name in array array['subjects','lectures','tasks','planner_sessions','focus_sessions'] loop
    execute format('drop trigger if exists %I on public.%I', table_name || '_updated_at', table_name);
    execute format('create trigger %I before update on public.%I for each row execute function public.set_updated_at()', table_name || '_updated_at', table_name);
    execute format('alter table public.%I enable row level security', table_name);

    foreach action_name in array array['select','insert','update','delete'] loop
      execute format('drop policy if exists %I on public.%I', table_name || '_' || action_name || '_own', table_name);
    end loop;

    execute format('create policy %I on public.%I for select to authenticated using ((select auth.uid()) = user_id)', table_name || '_select_own', table_name);
    execute format('create policy %I on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)', table_name || '_insert_own', table_name);
    execute format('create policy %I on public.%I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', table_name || '_update_own', table_name);
    execute format('create policy %I on public.%I for delete to authenticated using ((select auth.uid()) = user_id)', table_name || '_delete_own', table_name);
  end loop;
end;
$$;


-- Private study spaces and server-timed shared focus sessions.
create table if not exists public.study_spaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 80),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.study_space_members (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.study_spaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null default '',
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  unique (space_id, user_id),
  unique (id, space_id)
);
create index if not exists space_members_user_idx on public.study_space_members(user_id, space_id);

create table if not exists public.study_space_invitations (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.study_spaces(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  invite_code text not null unique,
  status text not null default 'active' check (status in ('active','revoked')),
  max_uses integer not null default 10 check (max_uses between 1 and 100),
  used_count integer not null default 0 check (used_count >= 0 and used_count <= max_uses),
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now()
);
create index if not exists invitations_space_idx on public.study_space_invitations(space_id, created_at desc);

create table if not exists public.shared_focus_sessions (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.study_spaces(id) on delete cascade,
  started_by uuid not null references auth.users(id) on delete restrict,
  duration_seconds integer not null check (duration_seconds between 60 and 86400),
  elapsed_seconds integer not null default 0 check (elapsed_seconds >= 0 and elapsed_seconds <= duration_seconds),
  status text not null default 'running' check (status in ('running','paused','completed','cancelled')),
  started_at timestamptz not null default now(),
  segment_started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'running' and segment_started_at is not null and ended_at is null)
      or (status = 'paused' and segment_started_at is null and ended_at is null)
      or (status in ('completed','cancelled') and segment_started_at is null and ended_at is not null))
);
create unique index if not exists shared_focus_one_open_per_space_idx
  on public.shared_focus_sessions(space_id) where status in ('running','paused');
create index if not exists shared_focus_space_created_idx on public.shared_focus_sessions(space_id, created_at desc);

create table if not exists public.shared_focus_participants (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.shared_focus_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null default '',
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  unique (session_id, user_id)
);
create index if not exists shared_focus_participants_session_idx on public.shared_focus_participants(session_id, joined_at);

-- SECURITY DEFINER membership predicate prevents recursive membership-table RLS checks.
create or replace function public.is_study_space_member(p_space_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.study_space_members m
    where m.space_id = p_space_id and m.user_id = (select auth.uid())
  );
$$;
revoke all on function public.is_study_space_member(uuid) from public;
grant execute on function public.is_study_space_member(uuid) to authenticated;

alter table public.study_spaces enable row level security;
alter table public.study_space_members enable row level security;
alter table public.study_space_invitations enable row level security;
alter table public.shared_focus_sessions enable row level security;
alter table public.shared_focus_participants enable row level security;

drop policy if exists study_spaces_select_member on public.study_spaces;
create policy study_spaces_select_member on public.study_spaces for select to authenticated
  using (public.is_study_space_member(id));
drop policy if exists space_members_select_member on public.study_space_members;
create policy space_members_select_member on public.study_space_members for select to authenticated
  using (public.is_study_space_member(space_id));
drop policy if exists shared_focus_select_member on public.shared_focus_sessions;
create policy shared_focus_select_member on public.shared_focus_sessions for select to authenticated
  using (public.is_study_space_member(space_id));
drop policy if exists shared_focus_participants_select_member on public.shared_focus_participants;
create policy shared_focus_participants_select_member on public.shared_focus_participants for select to authenticated
  using (exists (select 1 from public.shared_focus_sessions s where s.id = session_id and public.is_study_space_member(s.space_id)));

-- Mutating shared state is restricted to checked server functions.
drop policy if exists space_invitations_select_creator on public.study_space_invitations;
create policy space_invitations_select_creator on public.study_space_invitations for select to authenticated
  using (created_by = (select auth.uid()));

-- Create a space and its owner membership atomically.
create or replace function public.create_private_study_space(p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_space_id uuid;
  v_name text := trim(coalesce(p_name, ''));
  v_display_name text;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if char_length(v_name) < 1 or char_length(v_name) > 80 then raise exception 'Space name must be 1 to 80 characters'; end if;
  select coalesce(nullif(trim(p.display_name), ''), 'عضو') into v_display_name from public.profiles p where p.id = v_user_id;
  insert into public.study_spaces(name, created_by) values (v_name, v_user_id) returning id into v_space_id;
  insert into public.study_space_members(space_id, user_id, display_name, role) values (v_space_id, v_user_id, coalesce(v_display_name, 'عضو'), 'owner');
  return v_space_id;
end;
$$;

create or replace function public.create_study_space_invitation(p_space_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_code text;
begin
  if v_user_id is null or not public.is_study_space_member(p_space_id) then raise exception 'Study space membership required'; end if;
  v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 16));
  insert into public.study_space_invitations(space_id, created_by, invite_code)
  values (p_space_id, v_user_id, v_code);
  return v_code;
end;
$$;

create or replace function public.accept_study_space_invitation(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_invitation public.study_space_invitations%rowtype;
  v_display_name text;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  select * into v_invitation from public.study_space_invitations i
  where i.invite_code = upper(trim(coalesce(p_code, '')))
    and i.status = 'active' and i.expires_at > now() and i.used_count < i.max_uses
  for update;
  if not found then raise exception 'Invitation is invalid, expired, or already used'; end if;
  if exists (select 1 from public.study_space_members m where m.space_id = v_invitation.space_id and m.user_id = v_user_id) then return v_invitation.space_id; end if;
  select coalesce(nullif(trim(p.display_name), ''), 'عضو') into v_display_name from public.profiles p where p.id = v_user_id;
  insert into public.study_space_members(space_id, user_id, display_name, role)
  values (v_invitation.space_id, v_user_id, coalesce(v_display_name, 'عضو'), 'member')
  on conflict (space_id, user_id) do nothing;
  update public.study_space_invitations set used_count = used_count + 1 where id = v_invitation.id;
  return v_invitation.space_id;
end;
$$;

create or replace function public.start_shared_focus_session(p_space_id uuid, p_duration_seconds integer)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_session_id uuid;
  v_display_name text;
  v_now timestamptz := clock_timestamp();
begin
  if v_user_id is null or not public.is_study_space_member(p_space_id) then raise exception 'Study space membership required'; end if;
  if p_duration_seconds < 60 or p_duration_seconds > 86400 then raise exception 'Duration must be between 1 minute and 24 hours'; end if;
  select coalesce(nullif(trim(m.display_name), ''), 'عضو') into v_display_name from public.study_space_members m where m.space_id = p_space_id and m.user_id = v_user_id;
  insert into public.shared_focus_sessions(space_id, started_by, duration_seconds, status, started_at, segment_started_at)
  values (p_space_id, v_user_id, p_duration_seconds, 'running', v_now, v_now) returning id into v_session_id;
  insert into public.shared_focus_participants(session_id, user_id, display_name) values (v_session_id, v_user_id, coalesce(v_display_name, 'عضو'));
  return v_session_id;
end;
$$;

create or replace function public.join_shared_focus_session(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_space_id uuid;
  v_display_name text;
begin
  select s.space_id into v_space_id from public.shared_focus_sessions s where s.id = p_session_id and s.status in ('running','paused');
  if v_space_id is null or v_user_id is null or not public.is_study_space_member(v_space_id) then raise exception 'Active session and membership required'; end if;
  select coalesce(nullif(trim(m.display_name), ''), 'عضو') into v_display_name from public.study_space_members m where m.space_id = v_space_id and m.user_id = v_user_id;
  insert into public.shared_focus_participants(session_id, user_id, display_name)
  values (p_session_id, v_user_id, coalesce(v_display_name, 'عضو'))
  on conflict (session_id, user_id) do update set left_at = null;
end;
$$;

create or replace function public.control_shared_focus_session(p_session_id uuid, p_action text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.shared_focus_sessions%rowtype;
  v_now timestamptz := clock_timestamp();
  v_elapsed integer;
begin
  select * into v_session from public.shared_focus_sessions where id = p_session_id for update;
  if not found or not public.is_study_space_member(v_session.space_id) then raise exception 'Study space membership required'; end if;

  if p_action = 'pause' and v_session.status = 'running' then
    v_elapsed := least(v_session.duration_seconds, v_session.elapsed_seconds + greatest(0, floor(extract(epoch from (v_now - v_session.segment_started_at)))::integer));
    update public.shared_focus_sessions set elapsed_seconds = v_elapsed,
      status = case when v_elapsed >= duration_seconds then 'completed' else 'paused' end,
      segment_started_at = null,
      ended_at = case when v_elapsed >= duration_seconds then v_now else null end
      where id = p_session_id;
  elsif p_action = 'resume' and v_session.status = 'paused' then
    if v_session.elapsed_seconds >= v_session.duration_seconds then
      update public.shared_focus_sessions set status = 'completed', ended_at = v_now where id = p_session_id;
    else
      update public.shared_focus_sessions set status = 'running', segment_started_at = v_now where id = p_session_id;
    end if;
  elsif p_action in ('finish','cancel') and v_session.status in ('running','paused') then
    v_elapsed := v_session.elapsed_seconds;
    if v_session.status = 'running' then
      v_elapsed := least(v_session.duration_seconds, v_elapsed + greatest(0, floor(extract(epoch from (v_now - v_session.segment_started_at)))::integer));
    end if;
    update public.shared_focus_sessions set elapsed_seconds = v_elapsed,
      status = case when p_action = 'finish' then 'completed' else 'cancelled' end,
      segment_started_at = null, ended_at = v_now where id = p_session_id;
  else
    raise exception 'Invalid action for current shared session status';
  end if;
end;
$$;

create or replace function public.leave_shared_focus_session(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.shared_focus_participants set left_at = clock_timestamp()
  where session_id = p_session_id and user_id = (select auth.uid()) and left_at is null;
end;
$$;

revoke all on function public.create_private_study_space(text) from public;
revoke all on function public.create_study_space_invitation(uuid) from public;
revoke all on function public.accept_study_space_invitation(text) from public;
revoke all on function public.start_shared_focus_session(uuid, integer) from public;
revoke all on function public.join_shared_focus_session(uuid) from public;
revoke all on function public.control_shared_focus_session(uuid, text) from public;
revoke all on function public.leave_shared_focus_session(uuid) from public;
grant execute on function public.create_private_study_space(text) to authenticated;
grant execute on function public.create_study_space_invitation(uuid) to authenticated;
grant execute on function public.accept_study_space_invitation(text) to authenticated;
grant execute on function public.start_shared_focus_session(uuid, integer) to authenticated;
grant execute on function public.join_shared_focus_session(uuid) to authenticated;
grant execute on function public.control_shared_focus_session(uuid, text) to authenticated;
grant execute on function public.leave_shared_focus_session(uuid) to authenticated;

-- Enable Realtime for synchronized room state and participant presence.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'shared_focus_sessions') then
    alter publication supabase_realtime add table public.shared_focus_sessions;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'shared_focus_participants') then
    alter publication supabase_realtime add table public.shared_focus_participants;
  end if;
end;
$$;

drop trigger if exists shared_focus_updated_at on public.shared_focus_sessions;
create trigger shared_focus_updated_at before update on public.shared_focus_sessions for each row execute function public.set_updated_at();

-- Return a server timestamp only to an authenticated member, for a shared countdown anchor.
create or replace function public.get_shared_focus_server_time(p_space_id uuid)
returns timestamptz
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.is_study_space_member(p_space_id) then raise exception 'Study space membership required'; end if;
  return clock_timestamp();
end;
$$;
revoke all on function public.get_shared_focus_server_time(uuid) from public;
grant execute on function public.get_shared_focus_server_time(uuid) to authenticated;
-- Private Realtime chat and member presence for study spaces.
create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.study_spaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  sender_name text not null default '',
  body text not null check (char_length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists chat_messages_space_created_idx on public.chat_messages(space_id, created_at desc);

create table if not exists public.user_presence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'online' check (status in ('online','studying','on_break','away','offline')),
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.shares_study_space_with(p_other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.study_space_members mine
    join public.study_space_members theirs on theirs.space_id = mine.space_id
    where mine.user_id = (select auth.uid()) and theirs.user_id = p_other_user_id
  );
$$;
revoke all on function public.shares_study_space_with(uuid) from public;
grant execute on function public.shares_study_space_with(uuid) to authenticated;

alter table public.chat_messages enable row level security;
drop policy if exists chat_messages_select_member on public.chat_messages;
drop policy if exists chat_messages_insert_member on public.chat_messages;
create policy chat_messages_select_member on public.chat_messages for select to authenticated
  using (public.is_study_space_member(space_id));
create policy chat_messages_insert_member on public.chat_messages for insert to authenticated
  with check (user_id = (select auth.uid()) and public.is_study_space_member(space_id));

create or replace function public.set_chat_sender_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.user_id <> (select auth.uid()) or not public.is_study_space_member(new.space_id) then raise exception 'Study space membership required'; end if;
  select coalesce(nullif(trim(m.display_name), ''), 'عضو') into new.sender_name
  from public.study_space_members m where m.space_id = new.space_id and m.user_id = new.user_id;
  return new;
end;
$$;
drop trigger if exists chat_message_sender_name on public.chat_messages;
create trigger chat_message_sender_name before insert on public.chat_messages for each row execute function public.set_chat_sender_name();

alter table public.user_presence enable row level security;
drop policy if exists user_presence_select_self_or_partner on public.user_presence;
drop policy if exists user_presence_insert_self on public.user_presence;
drop policy if exists user_presence_update_self on public.user_presence;
create policy user_presence_select_self_or_partner on public.user_presence for select to authenticated
  using (user_id = (select auth.uid()) or public.shares_study_space_with(user_id));
-- Presence writes go through server-timestamp RPCs; clients cannot spoof last_seen_at.
drop trigger if exists user_presence_updated_at on public.user_presence;
create trigger user_presence_updated_at before update on public.user_presence for each row execute function public.set_updated_at();

create or replace function public.set_my_presence(p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if p_status not in ('online','studying','on_break','away','offline') then raise exception 'Invalid presence status'; end if;
  insert into public.user_presence(user_id, status, last_seen_at)
  values (v_user_id, p_status, clock_timestamp())
  on conflict (user_id) do update set status = excluded.status, last_seen_at = excluded.last_seen_at;
end;
$$;

create or replace function public.heartbeat_my_presence()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  insert into public.user_presence(user_id, status, last_seen_at)
  values (v_user_id, 'online', clock_timestamp())
  on conflict (user_id) do update set last_seen_at = excluded.last_seen_at;
end;
$$;
revoke all on function public.heartbeat_my_presence() from public;
grant execute on function public.heartbeat_my_presence() to authenticated;
revoke all on function public.set_my_presence(text) from public;
grant execute on function public.set_my_presence(text) to authenticated;

-- Enable private messages and presence in Supabase Realtime.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'chat_messages') then
    alter publication supabase_realtime add table public.chat_messages;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'user_presence') then
    alter publication supabase_realtime add table public.user_presence;
  end if;
end;
$$;




-- Private shared milestones and Little Moments.
create table if not exists public.study_milestones (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.study_spaces(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 80),
  description text not null default '' check (char_length(description) <= 500),
  icon_key text not null default 'sparkle'
    check (icon_key in ('sparkle','flag','favorite','school','celebration')),
  created_at timestamptz not null default now()
);

create index if not exists study_milestones_space_created_idx
  on public.study_milestones(space_id, created_at desc);

alter table public.study_milestones enable row level security;
drop policy if exists study_milestones_select_member on public.study_milestones;
create policy study_milestones_select_member on public.study_milestones
  for select to authenticated
  using (public.is_study_space_member(space_id));

drop policy if exists study_milestones_insert_member on public.study_milestones;
create policy study_milestones_insert_member on public.study_milestones
  for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and public.is_study_space_member(space_id)
  );

drop policy if exists study_milestones_delete_creator on public.study_milestones;
create policy study_milestones_delete_creator on public.study_milestones
  for delete to authenticated
  using (created_by = (select auth.uid()) and public.is_study_space_member(space_id));

grant select, insert, delete on public.study_milestones to authenticated;

-- Private account preferences and notification rules.
create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  week_starts_on smallint not null default 1 check (week_starts_on between 1 and 7),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  task_reminders_enabled boolean not null default true,
  overdue_task_reminders_enabled boolean not null default true,
  planner_reminders_enabled boolean not null default true,
  shared_activity_reminders_enabled boolean not null default true,
  encouragement_enabled boolean not null default true,
  reminder_lead_minutes integer not null default 15 check (reminder_lead_minutes in (0,5,15,30,60,1440)),
  quiet_hours_enabled boolean not null default false,
  quiet_hours_start time not null default time '22:00',
  quiet_hours_end time not null default time '07:00',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_settings enable row level security;
drop policy if exists user_settings_select_own on public.user_settings;
drop policy if exists user_settings_insert_own on public.user_settings;
drop policy if exists user_settings_update_own on public.user_settings;
create policy user_settings_select_own on public.user_settings
  for select to authenticated using (user_id = (select auth.uid()));
create policy user_settings_insert_own on public.user_settings
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy user_settings_update_own on public.user_settings
  for update to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

alter table public.notification_preferences enable row level security;
drop policy if exists notification_preferences_select_own on public.notification_preferences;
drop policy if exists notification_preferences_insert_own on public.notification_preferences;
drop policy if exists notification_preferences_update_own on public.notification_preferences;
create policy notification_preferences_select_own on public.notification_preferences
  for select to authenticated using (user_id = (select auth.uid()));
create policy notification_preferences_insert_own on public.notification_preferences
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy notification_preferences_update_own on public.notification_preferences
  for update to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop trigger if exists user_settings_updated_at on public.user_settings;
create trigger user_settings_updated_at before update on public.user_settings
  for each row execute function public.set_updated_at();
drop trigger if exists notification_preferences_updated_at on public.notification_preferences;
create trigger notification_preferences_updated_at before update on public.notification_preferences
  for each row execute function public.set_updated_at();

grant select, insert, update on public.user_settings to authenticated;
grant select, insert, update on public.notification_preferences to authenticated;

create or replace function public.update_my_display_name(p_display_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_name text := trim(coalesce(p_display_name, ''));
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if char_length(v_name) < 1 or char_length(v_name) > 80 then raise exception 'Display name must be 1 to 80 characters'; end if;
  update public.profiles set display_name = v_name where id = v_user_id;
  update public.study_space_members set display_name = v_name where user_id = v_user_id;
end;
$$;
revoke all on function public.update_my_display_name(text) from public;
grant execute on function public.update_my_display_name(text) to authenticated;

-- App-wide administrator role; separate from private-space owner/member roles.
create table if not exists public.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  granted_at timestamptz not null default now()
);

alter table public.app_admins enable row level security;
revoke all on table public.app_admins from public, anon, authenticated;
grant select on table public.app_admins to authenticated;
grant all on table public.app_admins to service_role;

drop policy if exists app_admins_select_self on public.app_admins;
create policy app_admins_select_self on public.app_admins
  for select to authenticated using (user_id = (select auth.uid()));

create or replace function public.is_app_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.app_admins
    where user_id = (select auth.uid())
  );
$$;
revoke all on function public.is_app_admin() from public;
grant execute on function public.is_app_admin() to authenticated;

drop trigger if exists bootstrap_studybridge_admin_after_insert on auth.users;
drop trigger if exists bootstrap_studybridge_admin_after_update on auth.users;
drop function if exists public.bootstrap_studybridge_admin();
