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
drop trigger if exists shared_focus_updated_at on public.shared_focus_sessions;
create trigger shared_focus_updated_at before update on public.shared_focus_sessions for each row execute function public.set_updated_at();

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

revoke all on function public.get_shared_focus_server_time(uuid) from public;
grant execute on function public.get_shared_focus_server_time(uuid) to authenticated;
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





