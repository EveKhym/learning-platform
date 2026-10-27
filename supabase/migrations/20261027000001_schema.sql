-- Applied to project gnairngsdzbrqpqxibnd on 2026-10-27.

-- Profiles ------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)));
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

-- Plans & subscriptions ----------------------------------------------
create table public.plans (
  id text primary key,
  name text not null,
  description text,
  price_cents integer not null default 0,
  billing_interval text not null default 'month' check (billing_interval in ('month','year')),
  features jsonb not null default '[]',
  is_premium boolean not null default false,
  sort_order integer not null default 0
);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  plan_id text not null references public.plans(id),
  status text not null check (status in ('trialing','active','past_due','canceled')),
  current_period_end timestamptz not null,
  cancel_at_period_end boolean not null default false,
  trial_used boolean not null default false,
  provider text not null default 'trial',
  provider_subscription_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.has_premium(uid uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.subscriptions s join public.plans p on p.id = s.plan_id
    where s.user_id = uid and p.is_premium
      and s.status in ('trialing','active') and s.current_period_end > now()
  );
$$;

-- Catalog -------------------------------------------------------------
create table public.courses (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  summary text,
  description text,
  category text not null default 'General',
  level text not null default 'Beginner' check (level in ('Beginner','Intermediate','Advanced')),
  emoji text not null default '📘',
  color text not null default '#4f46e5',
  is_premium boolean not null default false,
  published boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  position integer not null,
  title text not null,
  duration_minutes integer not null default 5,
  is_preview boolean not null default false,
  created_at timestamptz not null default now(),
  unique (course_id, position) deferrable initially deferred
);
create index on public.lessons (course_id);

-- Gated lesson body lives separately so the outline stays public.
create table public.lesson_content (
  lesson_id uuid primary key references public.lessons(id) on delete cascade,
  body text not null default '',
  video_url text
);

create table public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  position integer not null default 0,
  question text not null,
  options jsonb not null,
  correct_index integer not null
);
create index on public.quiz_questions (lesson_id);

create or replace function public.can_access_lesson(lid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.lessons l join public.courses c on c.id = l.course_id
    where l.id = lid and (c.published or public.is_admin())
      and (not c.is_premium or l.is_preview or public.has_premium() or public.is_admin())
  );
$$;

-- Learner data --------------------------------------------------------
create table public.enrollments (
  user_id uuid not null references auth.users(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  enrolled_at timestamptz not null default now(),
  last_lesson_id uuid references public.lessons(id) on delete set null,
  last_activity_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key (user_id, course_id)
);
create index on public.enrollments (course_id);

create table public.lesson_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  completed_at timestamptz not null default now(),
  quiz_score integer,
  quiz_total integer,
  primary key (user_id, lesson_id)
);
create index on public.lesson_progress (user_id, course_id);
create index on public.lesson_progress (lesson_id);
create index on public.lesson_progress (course_id);

create table public.lesson_notes (
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  body text not null default '',
  updated_at timestamptz not null default now(),
  primary key (user_id, lesson_id)
);
create index on public.lesson_notes (lesson_id);

create table public.certificates (
  id uuid primary key default gen_random_uuid(),
  code text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)),
  user_id uuid not null references auth.users(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  issued_at timestamptz not null default now(),
  unique (user_id, course_id)
);
create index on public.certificates (course_id);

-- RLS -----------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.plans enable row level security;
alter table public.subscriptions enable row level security;
alter table public.courses enable row level security;
alter table public.lessons enable row level security;
alter table public.lesson_content enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.enrollments enable row level security;
alter table public.lesson_progress enable row level security;
alter table public.lesson_notes enable row level security;
alter table public.certificates enable row level security;

create policy "own profile read" on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));
create policy "own profile update" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
-- Users may edit their name/avatar but never is_admin.
revoke update on public.profiles from authenticated, anon;
grant update (full_name, avatar_url) on public.profiles to authenticated;

create policy "plans readable" on public.plans for select to anon, authenticated using (true);

-- Subscriptions are read-only to users; writes go through functions / billing webhooks.
create policy "own subscription read" on public.subscriptions for select to authenticated
  using (user_id = (select auth.uid()));

create policy "published courses readable" on public.courses for select to anon, authenticated
  using (published or (select public.is_admin()));
create policy "admin manage courses" on public.courses for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "lessons outline readable" on public.lessons for select to anon, authenticated
  using (exists (select 1 from public.courses c where c.id = course_id and (c.published or (select public.is_admin()))));
create policy "admin manage lessons" on public.lessons for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "lesson content gated" on public.lesson_content for select to anon, authenticated
  using (public.can_access_lesson(lesson_id));
create policy "admin manage lesson content" on public.lesson_content for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "quiz gated" on public.quiz_questions for select to anon, authenticated
  using (public.can_access_lesson(lesson_id));
create policy "admin manage quiz" on public.quiz_questions for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
-- Learners must never see the answer key.
revoke select on public.quiz_questions from anon, authenticated;
grant select (id, lesson_id, position, question, options) on public.quiz_questions to anon, authenticated;

create policy "own enrollments read" on public.enrollments for select to authenticated
  using (user_id = (select auth.uid()));
create policy "own progress read" on public.lesson_progress for select to authenticated
  using (user_id = (select auth.uid()));
create policy "own certificates read" on public.certificates for select to authenticated
  using (user_id = (select auth.uid()));

create policy "own notes" on public.lesson_notes for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
