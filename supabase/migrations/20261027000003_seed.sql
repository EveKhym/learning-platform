-- Starter plans and courses. Safe to edit later from the admin page.

insert into public.plans (id, name, description, price_cents, billing_interval, features, is_premium, sort_order) values
  ('free', 'Free', 'Get started at no cost', 0, 'month',
   '["All free courses","Progress tracking & streaks","Personal lesson notes","Certificates for free courses"]', false, 0),
  ('pro_monthly', 'Pro', 'Everything, billed monthly', 1500, 'month',
   '["Every course, including Premium","Quizzes & certificates for all courses","Free 14-day trial","Cancel anytime"]', true, 1),
  ('pro_yearly', 'Pro Yearly', 'Everything, two months free', 15000, 'year',
   '["Everything in Pro","Save 17% vs monthly","Priority access to new courses"]', true, 2);

do $$
declare c uuid; l uuid;
begin
  ---------------------------------------------------------------------
  insert into public.courses (slug, title, summary, description, category, level, emoji, color, is_premium, published)
  values ('study-smarter', 'Study Smarter', 'Proven techniques to learn faster and remember more.',
    'A short, practical course on how learning actually works, and how to use that to get more out of every study session.',
    'Learning Skills', 'Beginner', '🧠', '#0ea5e9', false, true) returning id into c;

  insert into public.lessons (course_id, position, title, duration_minutes, is_preview) values (c, 1, 'How memory works', 6, true) returning id into l;
  insert into public.lesson_content values (l, E'## Your brain is not a hard drive\n\nMemories are **rebuilt** every time you recall them. Each time you pull something back out, you strengthen the path to it.\n\n### Key ideas\n\n- **Encoding**: getting information in. Attention matters most here.\n- **Storage**: sleep consolidates what you learned during the day.\n- **Retrieval**: practising recall is what makes memories stick.\n\n> The act of remembering is itself a powerful form of learning.\n\nIn the next lessons we will turn these ideas into habits you can use today.', null);
  insert into public.quiz_questions (lesson_id, position, question, options, correct_index) values
    (l, 0, 'What strengthens a memory the most?', '["Re-reading notes","Practising recall","Highlighting"]', 1),
    (l, 1, 'When does the brain consolidate new memories?', '["During sleep","While multitasking","Only during exams"]', 0);

  insert into public.lessons (course_id, position, title, duration_minutes) values (c, 2, 'Active recall', 7) returning id into l;
  insert into public.lesson_content values (l, E'## Test yourself, don''t just review\n\nActive recall means closing the book and asking: *what do I remember?*\n\n1. Read a section once.\n2. Close it and write down everything you can.\n3. Check what you missed and repeat.\n\nIt feels harder than re-reading. That difficulty is exactly why it works.', null);
  insert into public.quiz_questions (lesson_id, position, question, options, correct_index) values
    (l, 0, 'Which is an example of active recall?', '["Re-reading a chapter","Writing what you remember with the book closed","Copying notes neatly"]', 1);

  insert into public.lessons (course_id, position, title, duration_minutes) values (c, 3, 'Spaced repetition', 6) returning id into l;
  insert into public.lesson_content values (l, E'## Spread it out\n\nReviewing something **1 day, 3 days, 1 week and 1 month** after learning it beats cramming by a wide margin.\n\n- Short, regular sessions > one long session\n- Review just as you are about to forget\n- Flashcard apps can schedule this for you\n\nThis is also why keeping a daily learning streak on this platform pays off.', null);

  insert into public.lessons (course_id, position, title, duration_minutes) values (c, 4, 'Building a study routine', 5) returning id into l;
  insert into public.lesson_content values (l, E'## Make it automatic\n\n- Pick a **fixed time** and place.\n- Start with just **15 minutes**.\n- Remove distractions: phone in another room.\n- End each session by writing what you will do next time.\n\nCongratulations, finishing this lesson completes the course and earns your certificate! 🎉', null);
  insert into public.quiz_questions (lesson_id, position, question, options, correct_index) values
    (l, 0, 'What is a good length for a first study habit?', '["3 hours","15 minutes","Whenever you feel like it"]', 1);

  ---------------------------------------------------------------------
  insert into public.courses (slug, title, summary, description, category, level, emoji, color, is_premium, published)
  values ('web-basics', 'Web Basics: HTML & CSS', 'Build your first web page from scratch.',
    'Learn how websites are structured with HTML and styled with CSS. No experience needed.',
    'Technology', 'Beginner', '🌐', '#4f46e5', false, true) returning id into c;

  insert into public.lessons (course_id, position, title, duration_minutes, is_preview) values (c, 1, 'What is HTML?', 8, true) returning id into l;
  insert into public.lesson_content values (l, E'## The skeleton of the web\n\nHTML describes the **structure** of a page using tags:\n\n```html\n<h1>Hello!</h1>\n<p>This is a paragraph.</p>\n<a href="https://example.com">A link</a>\n```\n\nEvery page has a `<head>` (information about the page) and a `<body>` (what you see).', null);
  insert into public.quiz_questions (lesson_id, position, question, options, correct_index) values
    (l, 0, 'Which tag makes a top-level heading?', '["<p>","<h1>","<a>"]', 1),
    (l, 1, 'Where does visible page content go?', '["<head>","<body>","<title>"]', 1);

  insert into public.lessons (course_id, position, title, duration_minutes) values (c, 2, 'Styling with CSS', 9) returning id into l;
  insert into public.lesson_content values (l, E'## Making it look good\n\nCSS uses **selectors** and **properties**:\n\n```css\nh1 {\n  color: rebeccapurple;\n  font-size: 2rem;\n}\n```\n\nTry changing colours, fonts and spacing (`margin`, `padding`) on your own page.', null);

  insert into public.lessons (course_id, position, title, duration_minutes) values (c, 3, 'Layouts with Flexbox', 10) returning id into l;
  insert into public.lesson_content values (l, E'## Lining things up\n\n```css\n.row {\n  display: flex;\n  gap: 16px;\n  justify-content: space-between;\n}\n```\n\nFlexbox arranges children in a row (or column) and handles spacing for you.', null);
  insert into public.quiz_questions (lesson_id, position, question, options, correct_index) values
    (l, 0, 'Which property turns on Flexbox?', '["display: flex","position: flex","flex: on"]', 0);

  ---------------------------------------------------------------------
  insert into public.courses (slug, title, summary, description, category, level, emoji, color, is_premium, published)
  values ('javascript-fundamentals', 'JavaScript Fundamentals', 'Make web pages interactive with real code.',
    'Variables, functions, arrays, and the DOM: everything you need to start writing JavaScript with confidence.',
    'Technology', 'Intermediate', '⚡', '#f59e0b', true, true) returning id into c;

  insert into public.lessons (course_id, position, title, duration_minutes, is_preview) values (c, 1, 'Variables and types', 10, true) returning id into l;
  insert into public.lesson_content values (l, E'## Storing values\n\n```js\nconst name = "Ada";   // can''t be reassigned\nlet score = 0;        // can change\nscore = score + 10;\n```\n\nCommon types: **string**, **number**, **boolean**, **array**, **object**.', null);
  insert into public.quiz_questions (lesson_id, position, question, options, correct_index) values
    (l, 0, 'Which keyword declares a value that can be reassigned?', '["const","let","fixed"]', 1);

  insert into public.lessons (course_id, position, title, duration_minutes) values (c, 2, 'Functions', 12) returning id into l;
  insert into public.lesson_content values (l, E'## Reusable steps\n\n```js\nfunction greet(name) {\n  return `Hello, ${name}!`;\n}\n\nconst add = (a, b) => a + b;\n```\n\nFunctions take **inputs** (parameters) and **return** an output.', null);
  insert into public.quiz_questions (lesson_id, position, question, options, correct_index) values
    (l, 0, 'What does `add(2, 3)` return for `const add = (a, b) => a + b`?', '["23","5","undefined"]', 1);

  insert into public.lessons (course_id, position, title, duration_minutes) values (c, 3, 'Arrays and loops', 12) returning id into l;
  insert into public.lesson_content values (l, E'## Working with lists\n\n```js\nconst fruits = ["apple", "pear", "fig"];\nfor (const f of fruits) console.log(f);\nconst loud = fruits.map(f => f.toUpperCase());\n```', null);

  insert into public.lessons (course_id, position, title, duration_minutes) values (c, 4, 'The DOM', 14) returning id into l;
  insert into public.lesson_content values (l, E'## Changing the page\n\n```js\nconst button = document.querySelector("button");\nbutton.addEventListener("click", () => {\n  document.body.style.background = "lavender";\n});\n```\n\nThe DOM is JavaScript''s live view of your HTML.', null);
  insert into public.quiz_questions (lesson_id, position, question, options, correct_index) values
    (l, 0, 'Which method finds the first matching element?', '["document.find()","document.querySelector()","document.getAll()"]', 1);

  ---------------------------------------------------------------------
  insert into public.courses (slug, title, summary, description, category, level, emoji, color, is_premium, published)
  values ('money-essentials', 'Personal Finance Essentials', 'Budgeting, saving and planning with confidence.',
    'A calm, judgement-free introduction to managing your money: budgets, emergency funds and long-term goals.',
    'Life Skills', 'Beginner', '💰', '#10b981', true, true) returning id into c;

  insert into public.lessons (course_id, position, title, duration_minutes, is_preview) values (c, 1, 'Where does my money go?', 8, true) returning id into l;
  insert into public.lesson_content values (l, E'## Track before you plan\n\nFor one month, write down every expense. Group them into:\n\n- **Needs**: rent, groceries, transport\n- **Wants**: dining out, subscriptions\n- **Goals**: savings, paying off debt\n\nNo judgement, just data.', null);

  insert into public.lessons (course_id, position, title, duration_minutes) values (c, 2, 'The 50/30/20 budget', 9) returning id into l;
  insert into public.lesson_content values (l, E'## A simple starting point\n\n- **50%** needs\n- **30%** wants\n- **20%** savings and debt repayment\n\nAdjust the numbers to fit your life; the point is to decide on purpose.', null);
  insert into public.quiz_questions (lesson_id, position, question, options, correct_index) values
    (l, 0, 'In 50/30/20, what is the 20% for?', '["Wants","Needs","Savings and debt repayment"]', 2);

  insert into public.lessons (course_id, position, title, duration_minutes) values (c, 3, 'Building an emergency fund', 7) returning id into l;
  insert into public.lesson_content values (l, E'## Your financial safety net\n\nAim for **3 to 6 months** of essential expenses in an easy-access savings account. Start with a first goal of one month.', null);
  insert into public.quiz_questions (lesson_id, position, question, options, correct_index) values
    (l, 0, 'A common emergency fund target is…', '["1 week of expenses","3 to 6 months of essential expenses","5 years of income"]', 1);
end $$;
