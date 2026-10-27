// Shared client for every page. Load after supabase-js (and marked/DOMPurify where lessons render).
// The anon key is public by design; all access control lives in Postgres RLS + functions.
(function () {
  const SUPABASE_URL = "https://gnairngsdzbrqpqxibnd.supabase.co";
  const SUPABASE_ANON_KEY =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImduYWlybmdzZHpicnFwcXhpYm5kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxMjY4MTgsImV4cCI6MjEwODcwMjgxOH0.3arkT44JnZ7O3oU5ULU_6ClFooHVqiA2ME6xjNVIUTA";

  const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  const esc = (value) =>
    String(value ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

  const $ = (sel, root = document) => root.querySelector(sel);
  const param = (name) => new URLSearchParams(location.search).get(name);

  function toast(message) {
    let el = document.getElementById("toast");
    if (!el) {
      el = document.createElement("div");
      el.id = "toast";
      el.setAttribute("role", "status");
      document.body.appendChild(el);
    }
    el.textContent = message;
    el.classList.add("show");
    clearTimeout(el._timer);
    el._timer = setTimeout(() => el.classList.remove("show"), 3200);
  }

  function showAlert(el, message, kind = "error") {
    el.className = `alert ${kind}`;
    el.textContent = message;
    el.classList.remove("hidden");
  }

  // Turns Postgres "raise exception" and auth errors into friendly text.
  const errorText = (error) => error?.message || "Something went wrong. Please try again.";

  async function getSession() {
    const { data } = await sb.auth.getSession();
    return data.session;
  }

  let profilePromise;
  function getProfile() {
    profilePromise ??= (async () => {
      const session = await getSession();
      if (!session) return null;
      const [{ data: profile }, { data: subscription }] = await Promise.all([
        sb.from("profiles").select("*").eq("id", session.user.id).maybeSingle(),
        sb.from("subscriptions").select("*, plans(*)").eq("user_id", session.user.id).maybeSingle(),
      ]);
      const premium =
        !!subscription &&
        subscription.plans?.is_premium &&
        ["trialing", "active"].includes(subscription.status) &&
        new Date(subscription.current_period_end) > new Date();
      return { user: session.user, profile: profile || {}, subscription, premium };
    })();
    return profilePromise;
  }

  // Redirects to login (and back again afterwards) when signed out.
  async function requireAuth() {
    const me = await getProfile();
    if (!me) {
      location.href = `login.html?next=${encodeURIComponent(location.pathname.split("/").pop() + location.search)}`;
      throw new Error("redirecting");
    }
    return me;
  }

  async function renderNav() {
    const nav = document.createElement("header");
    nav.className = "nav";
    const here = location.pathname.split("/").pop() || "index.html";
    const link = (href, label) =>
      `<a href="${href}"${href === here ? ' aria-current="page"' : ""}>${label}</a>`;
    nav.innerHTML = `<div class="nav-inner">
      <a class="brand" href="index.html">My Learning <span>Platform</span></a>
      <nav class="nav-links" aria-label="Main">${link("courses.html", "Courses")}${link("pricing.html", "Pricing")}<span id="nav-auth"></span></nav>
    </div>`;
    document.body.prepend(nav);

    const footer = document.createElement("footer");
    footer.className = "footer";
    footer.innerHTML = `© ${new Date().getFullYear()} My Learning Platform · <a href="verify.html">Verify a certificate</a>`;
    document.body.append(footer);

    const me = await getProfile();
    const slot = $("#nav-auth");
    slot.style.display = "contents";
    slot.innerHTML = me
      ? link("dashboard.html", "Dashboard") +
        (me.profile.is_admin ? link("admin.html", "Admin") : "") +
        link("account.html", "Account")
      : `${link("login.html", "Log in")} <a class="button small" href="login.html?mode=signup">Sign up free</a>`;
  }

  sb.auth.onAuthStateChange((event) => {
    if (event === "SIGNED_OUT") profilePromise = undefined;
  });

  const formatPrice = (plan) =>
    plan.price_cents === 0 ? "Free" : `$${(plan.price_cents / 100).toFixed(plan.price_cents % 100 ? 2 : 0)}`;

  const formatDate = (iso) => new Date(iso).toLocaleDateString(undefined, { year: "numeric", month: "long", day: "numeric" });

  function renderMarkdown(md) {
    return DOMPurify.sanitize(marked.parse(md || ""));
  }

  // Accepts YouTube / Vimeo links or direct video files.
  function videoEmbed(url) {
    if (!url) return "";
    const yt = url.match(/(?:youtube\.com\/(?:watch\?v=|embed\/)|youtu\.be\/)([\w-]{11})/);
    const vimeo = url.match(/vimeo\.com\/(\d+)/);
    let src;
    if (yt) src = `https://www.youtube-nocookie.com/embed/${yt[1]}`;
    else if (vimeo) src = `https://player.vimeo.com/video/${vimeo[1]}`;
    if (src) return `<div class="video"><iframe src="${src}" title="Lesson video" allow="fullscreen; picture-in-picture" allowfullscreen></iframe></div>`;
    if (/^https:\/\//.test(url)) return `<div class="video"><video src="${esc(url)}" controls></video></div>`;
    return "";
  }

  function courseCard(course, progress) {
    const pct = progress?.total ? Math.round((progress.done / progress.total) * 100) : null;
    return `<a class="card course-card" href="course.html?slug=${encodeURIComponent(course.slug)}">
      <div class="course-cover" style="background:color-mix(in srgb, ${esc(course.color)} 18%, transparent)">${esc(course.emoji)}</div>
      <div class="course-body">
        <div class="row">
          <span class="badge ${course.is_premium ? "premium" : "free"}">${course.is_premium ? "★ Premium" : "Free"}</span>
          <span class="badge">${esc(course.level)}</span>
        </div>
        <h3>${esc(course.title)}</h3>
        <p>${esc(course.summary)}</p>
        ${
          pct === null
            ? `<span class="subtle">${esc(course.category)}</span>`
            : `<div class="progress${pct === 100 ? " done" : ""}"><span style="width:${pct}%"></span></div>
               <span class="subtle">${pct === 100 ? "Completed 🎉" : `${progress.done} of ${progress.total} lessons · ${pct}%`}</span>`
        }
      </div>
    </a>`;
  }

  window.App = {
    sb, esc, $, param, toast, showAlert, errorText, getSession, getProfile, requireAuth,
    renderNav, formatPrice, formatDate, renderMarkdown, videoEmbed, courseCard,
  };
})();
