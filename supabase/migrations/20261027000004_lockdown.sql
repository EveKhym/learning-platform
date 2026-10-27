-- Run this once in the Supabase SQL editor (Dashboard > SQL > New query).
-- The MCP tool's safety gate blocked it because it contains REVOKE / DELETE.

create or replace function public.admin_save_quiz(p_lesson_id uuid, p_questions jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  delete from public.quiz_questions where lesson_id = p_lesson_id;
  insert into public.quiz_questions (lesson_id, position, question, options, correct_index)
  select p_lesson_id, (ord - 1)::int, q->>'question', q->'options', (q->>'correct_index')::int
  from jsonb_array_elements(p_questions) with ordinality as t(q, ord);
end $$;

-- Lock down execution: Postgres grants EXECUTE to PUBLIC by default.
-- is_admin / can_access_lesson stay callable because RLS policies use them.
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.verify_certificate(text), public.is_admin(), public.can_access_lesson(uuid) to anon;
grant execute on function public.enroll(uuid), public.complete_lesson(uuid), public.touch_lesson(uuid),
  public.submit_quiz(uuid, jsonb), public.get_learning_stats(), public.verify_certificate(text),
  public.start_trial(text), public.set_cancel_at_period_end(boolean),
  public.is_admin(), public.can_access_lesson(uuid), public.admin_get_quiz(uuid),
  public.admin_save_quiz(uuid, jsonb), public.admin_overview() to authenticated;
