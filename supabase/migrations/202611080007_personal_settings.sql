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

grant select, insert, update on public.user_settings to authenticated;
grant select, insert, update on public.notification_preferences to authenticated;
