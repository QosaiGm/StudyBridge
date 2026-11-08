-- Private academic records. Every row belongs to one authenticated user.
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

-- The timestamp trigger function is created by migration 202611070001_profiles.sql.
do $$ declare t text; action text; begin
  foreach t in array array['subjects','lectures','tasks','planner_sessions'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_updated_at', t);
    execute format('create trigger %I before update on public.%I for each row execute function public.set_updated_at()', t || '_updated_at', t);
    execute format('alter table public.%I enable row level security', t);
    foreach action in array array['select','insert','update','delete'] loop
      execute format('drop policy if exists %I on public.%I', t || '_' || action || '_own', t);
    end loop;
    execute format('create policy %I on public.%I for select to authenticated using ((select auth.uid()) = user_id)', t || '_select_own', t);
    execute format('create policy %I on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)', t || '_insert_own', t);
    execute format('create policy %I on public.%I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t || '_update_own', t);
    execute format('create policy %I on public.%I for delete to authenticated using ((select auth.uid()) = user_id)', t || '_delete_own', t);
  end loop;
end $$;
