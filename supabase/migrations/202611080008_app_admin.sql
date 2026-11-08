-- App-wide admin identities are separate from study_space_members.role (owner/member).
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
