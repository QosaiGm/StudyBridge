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
