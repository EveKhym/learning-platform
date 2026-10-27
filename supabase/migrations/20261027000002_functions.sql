-- Server-side logic. All learner writes (progress, quizzes, certificates,
-- subscriptions) go through these functions so they can't be spoofed client-side.

create or replace function public.enroll(p_course_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if not exists (select 1 from public.courses where id = p_course_id and published) then
    raise exception 'Course not found';
  end if;
  insert into public.enrollments (user_id, course_id) values (auth.uid(), p_course_id)
  on conflict do nothing;
end $$;

-- Issues a certificate once every lesson in the course is complete.
create or replace function public.refresh_course_completion(p_user uuid, p_course uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare total int; done int;
begin
  select count(*) into total from public.lessons where course_id = p_course;
  select count(*) into done from public.lesson_progress where user_id = p_user and course_id = p_course;
  if total > 0 and done >= total then
    update public.enrollments set completed_at = coalesce(completed_at, now())
      where user_id = p_user and course_id = p_course;
    insert into public.certificates (user_id, course_id) values (p_user, p_course) on conflict do nothing;
    return true;
  end if;
  return false;
end $$;

create or replace function public.complete_lesson(p_lesson_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_course uuid; v_done boolean;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if not public.can_access_lesson(p_lesson_id) then raise exception 'Upgrade required to access this lesson'; end if;
  select course_id into v_course from public.lessons where id = p_lesson_id;

  insert into public.enrollments (user_id, course_id) values (auth.uid(), v_course) on conflict do nothing;
  insert into public.lesson_progress (user_id, lesson_id, course_id) values (auth.uid(), p_lesson_id, v_course)
    on conflict do nothing;
  update public.enrollments set last_lesson_id = p_lesson_id, last_activity_at = now()
    where user_id = auth.uid() and course_id = v_course;

  v_done := public.refresh_course_completion(auth.uid(), v_course);
  return jsonb_build_object('course_completed', v_done);
end $$;

-- Records "last opened" so the dashboard can offer Continue learning.
create or replace function public.touch_lesson(p_lesson_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_course uuid;
begin
  if auth.uid() is null or not public.can_access_lesson(p_lesson_id) then return; end if;
  select course_id into v_course from public.lessons where id = p_lesson_id;
  insert into public.enrollments (user_id, course_id, last_lesson_id) values (auth.uid(), v_course, p_lesson_id)
  on conflict (user_id, course_id) do update set last_lesson_id = excluded.last_lesson_id, last_activity_at = now();
end $$;

-- Grades a quiz server-side; passing (>= 70%) completes the lesson.
create or replace function public.submit_quiz(p_lesson_id uuid, p_answers jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_total int; v_score int; v_passed boolean; v_result jsonb; v_completion jsonb;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if not public.can_access_lesson(p_lesson_id) then raise exception 'Upgrade required to access this lesson'; end if;

  select count(*),
         count(*) filter (where (p_answers->>(q.id::text))::int = q.correct_index),
         jsonb_object_agg(q.id::text, q.correct_index)
    into v_total, v_score, v_result
  from public.quiz_questions q where q.lesson_id = p_lesson_id;

  if v_total = 0 then raise exception 'This lesson has no quiz'; end if;
  v_passed := v_score * 10 >= v_total * 7;

  if v_passed then
    v_completion := public.complete_lesson(p_lesson_id);
    update public.lesson_progress set quiz_score = greatest(coalesce(quiz_score, 0), v_score), quiz_total = v_total
      where user_id = auth.uid() and lesson_id = p_lesson_id;
  end if;

  return jsonb_build_object('score', v_score, 'total', v_total, 'passed', v_passed,
    'correct', case when v_passed then v_result end,
    'course_completed', coalesce((v_completion->>'course_completed')::boolean, false));
end $$;

create or replace function public.get_learning_stats()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_days date[]; v_streak int := 0; v_day date; v_longest int := 0; v_run int := 0; v_prev date;
begin
  if auth.uid() is null then return null; end if;
  select array_agg(d order by d desc) into v_days from (
    select distinct (completed_at at time zone 'utc')::date d from public.lesson_progress where user_id = auth.uid()) x;

  if v_days is not null then
    -- Current streak: consecutive days ending today or yesterday.
    v_day := (now() at time zone 'utc')::date;
    if v_days[1] < v_day then v_day := v_day - 1; end if;
    foreach v_prev in array v_days loop
      exit when v_prev <> v_day;
      v_streak := v_streak + 1; v_day := v_day - 1;
    end loop;
    v_prev := null;
    foreach v_day in array v_days loop
      if v_prev is not null and v_prev - v_day = 1 then v_run := v_run + 1; else v_run := 1; end if;
      v_longest := greatest(v_longest, v_run); v_prev := v_day;
    end loop;
  end if;

  return jsonb_build_object(
    'lessons_completed', (select count(*) from public.lesson_progress where user_id = auth.uid()),
    'minutes_learned', (select coalesce(sum(l.duration_minutes), 0) from public.lesson_progress p
                        join public.lessons l on l.id = p.lesson_id where p.user_id = auth.uid()),
    'courses_enrolled', (select count(*) from public.enrollments where user_id = auth.uid()),
    'courses_completed', (select count(*) from public.enrollments where user_id = auth.uid() and completed_at is not null),
    'current_streak', v_streak,
    'longest_streak', v_longest,
    'activity', (select coalesce(jsonb_object_agg(d, n), '{}') from (
        select (completed_at at time zone 'utc')::date::text d, count(*) n from public.lesson_progress
        where user_id = auth.uid() and completed_at > now() - interval '120 days' group by 1) a)
  );
end $$;

-- Public certificate verification by code.
create or replace function public.verify_certificate(p_code text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('code', c.code, 'issued_at', c.issued_at, 'learner', p.full_name,
                            'course', co.title, 'course_slug', co.slug)
  from public.certificates c
  join public.profiles p on p.id = c.user_id
  join public.courses co on co.id = c.course_id
  where c.code = upper(trim(p_code));
$$;

-- Free trial: one per account. Paid activation should come from a billing webhook (service role).
create or replace function public.start_trial(p_plan_id text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if not exists (select 1 from public.plans where id = p_plan_id and is_premium) then raise exception 'Unknown plan'; end if;
  if exists (select 1 from public.subscriptions where user_id = auth.uid() and trial_used) then
    raise exception 'Your free trial has already been used';
  end if;
  insert into public.subscriptions (user_id, plan_id, status, current_period_end, trial_used)
  values (auth.uid(), p_plan_id, 'trialing', now() + interval '14 days', true)
  on conflict (user_id) do update set plan_id = excluded.plan_id, status = 'trialing',
    current_period_end = excluded.current_period_end, trial_used = true, cancel_at_period_end = false, updated_at = now();
end $$;

create or replace function public.set_cancel_at_period_end(p_cancel boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  update public.subscriptions set cancel_at_period_end = p_cancel, updated_at = now()
    where user_id = auth.uid() and status in ('trialing','active');
  if not found then raise exception 'No active subscription'; end if;
end $$;

-- Admin helpers (the answer key is hidden from normal column grants).
create or replace function public.admin_get_quiz(p_lesson_id uuid)
returns setof public.quiz_questions language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  return query select * from public.quiz_questions where lesson_id = p_lesson_id order by position;
end $$;

create or replace function public.admin_overview()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  return jsonb_build_object(
    'learners', (select count(*) from public.profiles),
    'premium', (select count(*) from public.subscriptions s join public.plans p on p.id = s.plan_id
                where p.is_premium and s.status in ('trialing','active') and s.current_period_end > now()),
    'enrollments', (select count(*) from public.enrollments),
    'completions', (select count(*) from public.certificates),
    'lessons_completed_7d', (select count(*) from public.lesson_progress where completed_at > now() - interval '7 days'));
end $$;

