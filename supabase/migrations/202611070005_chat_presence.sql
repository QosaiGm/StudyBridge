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


