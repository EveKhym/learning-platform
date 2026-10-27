# My Learning Platform

A subscription-style learning platform: plain HTML/CSS/JS on the front end, [Supabase](https://supabase.com) (Postgres + Auth) on the back end. There is no build step.

## Features

- **Accounts**: sign up, log in, log out, password reset, and profile editing (Supabase Auth, email + password)
- **Course catalog**: search plus filters for category, level, and Free vs Premium
- **Courses & lessons**: Markdown lessons, optional YouTube/Vimeo/MP4 video, and free preview lessons in Premium courses
- **Progress tracking**: per-lesson completion, course progress bars, a "continue where you left off" link, a daily streak, minutes learned, and an activity heatmap
- **Quizzes**: graded on the server (learners can never read the answer key); a score of 70% completes the lesson
- **Certificates**: issued automatically when a course is finished, printable, with a public verification page
- **Subscriptions**: Free / Pro / Pro Yearly plans, a 14-day free trial (one per account), and cancel/resume at period end. Premium content is locked in the database, not just hidden in the UI
- **Lesson notes**: private, autosaved notes on each lesson
- **Admin**: create, edit, and delete courses, lessons, and quizzes, plus platform stats

## Pages

| Page | Purpose |
| --- | --- |
| `index.html` | Landing page |
| `login.html`, `reset.html` | Auth |
| `courses.html`, `course.html?slug=` | Catalog and course detail |
| `lesson.html?id=` | Lesson player, quiz, notes |
| `dashboard.html` | Learner stats, my courses, certificates |
| `pricing.html`, `account.html` | Plans, trial, subscription management |
| `certificate.html?code=`, `verify.html` | Certificates |
| `admin.html` | Content management (admins only) |

## Running locally

Serve the folder over HTTP, because Supabase auth email links need a real URL. For example:

```sh
npx serve .            # or: python -m http.server 8000
```

Then, in the Supabase dashboard under **Authentication → URL Configuration**, set **Site URL** to your local or production address and add it to **Redirect URLs**.

## Database

The SQL lives in `supabase/migrations/`:

1. `…01_schema.sql`: tables, row-level security, and column grants *(applied)*
2. `…02_functions.sql`: RPCs for enrolling, completing lessons, quizzes, stats, and trials *(applied)*
3. `…03_seed.sql`: plans and 4 starter courses *(applied)*
4. `…04_lockdown.sql`: the admin quiz-save function and the function permission lockdown. **Run this one by hand in the SQL editor.**

Make yourself an admin after signing up:

```sql
update public.profiles set is_admin = true
where id = (select id from auth.users where email = 'you@example.com');
```

## Taking payments (next step)

The free trial works today. Paid "Subscribe" buttons show a "coming soon" message until a payment provider is connected. With Stripe:

1. Create a Supabase Edge Function that opens a Stripe Checkout session for a plan.
2. Create a second Edge Function for the Stripe webhook. Using the service role key, it upserts `public.subscriptions` (`status`, `current_period_end`, `provider = 'stripe'`, `provider_subscription_id`).
3. Point the `[data-checkout]` handler in `pricing.html` at the checkout function.

Learners can't write to `subscriptions` directly, so access only changes through trusted server code.
