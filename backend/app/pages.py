"""Public web pages the App Store listing links to: privacy policy and support.

Review the wording before launch. This is a plain-language starting point, not legal advice.
"""

from __future__ import annotations

import html
import os

SUPPORT_EMAIL = os.environ.get("SCOUT_SUPPORT_EMAIL", "")
UPDATED = "November 2026"

_STYLE = """
<style>
  :root { --bg:#FFF7EC; --card:#fff; --ink:#2B2240; --soft:#6E6585; --accent:#7B61FF; }
  @media (prefers-color-scheme: dark) { :root { --bg:#15131D; --card:#23202E; --ink:#F4F1FA; --soft:#A9A2BC; --accent:#9D8BFF; } }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--ink);
         font: 17px/1.6 ui-rounded, -apple-system, system-ui, sans-serif; }
  main { max-width: 720px; margin: 0 auto; padding: 32px 16px 64px; }
  .card { background:var(--card); border-radius:24px; padding:24px; margin-bottom:16px; }
  h1 { font-size: 30px; margin: 0 0 4px; }
  h2 { font-size: 20px; margin: 0 0 8px; }
  p, li { color: var(--ink); }
  .soft { color: var(--soft); }
  a { color: var(--accent); font-weight: 600; }
</style>
"""


def _contact_line() -> str:
    if SUPPORT_EMAIL:
        email = html.escape(SUPPORT_EMAIL)
        return f'Email us at <a href="mailto:{email}">{email}</a>.'
    return "Use the support link on Screen Scout's App Store page."


def _page(title: str, body: str) -> str:
    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>{_STYLE}</head>
<body><main>{body}</main></body></html>"""


def privacy_policy() -> str:
    return _page("Screen Scout Privacy Policy", f"""
<div class="card">
  <h1>Privacy Policy</h1>
  <p class="soft">Screen Scout · Last updated {UPDATED}</p>
  <p>Screen Scout helps parents check what's in an online video before their kids watch it.
  This page explains what we collect, why, and how to delete it.</p>
</div>

<div class="card">
  <h2>What we collect</h2>
  <ul>
    <li><b>Your Sign in with Apple details:</b> an anonymous Apple user ID, and the name and
        email Apple shares with us. Apple lets you hide your real email.</li>
    <li><b>Your family:</b> the family name, who's in it, and the kid profiles you add
        (a first name and an age).</li>
    <li><b>Videos you scout:</b> the video links you submit and the reports we create,
        plus how many reviews your family runs each month.</li>
    <li><b>Basic server logs:</b> like most online services, our server keeps short-term
        technical logs such as IP addresses to keep things running and secure.</li>
  </ul>
</div>

<div class="card">
  <h2>How we use it</h2>
  <ul>
    <li>To sign you in and keep your family's reviews in sync across devices.</li>
    <li>To create reviews. We send the video's public details, captions, and still frames
        to Anthropic's Claude AI service, which writes the report. We don't send your name,
        email, or kids' names with them.</li>
    <li>To apply monthly review limits.</li>
  </ul>
  <p>We don't sell your data, show ads, or use third-party tracking or analytics.</p>
</div>

<div class="card">
  <h2>Kids' privacy</h2>
  <p>Screen Scout is made for parents and isn't meant to be used by children. We don't
  knowingly collect information from kids. Kid profiles contain only what a parent enters:
  a first name and an age.</p>
</div>

<div class="card">
  <h2>Sharing</h2>
  <p>Reports are shared with the members of your family in the app. Video reports themselves
  don't contain personal information, so if another family scouts the same video, they may
  see the same report. We share data with service providers only to run Screen Scout
  (Apple for sign-in, Anthropic for AI analysis, and our hosting provider).</p>
</div>

<div class="card">
  <h2>Deleting your data</h2>
  <p>Delete your account anytime in the app: tap your profile, then <b>Delete Account</b>.
  This removes your account and sign-in. If you were the last person in your family, the
  family, its kid profiles, and its list of reviews are deleted too. Reviews you shared with
  other family members stay with them.</p>
</div>

<div class="card">
  <h2>Questions</h2>
  <p>{_contact_line()}</p>
</div>
""")


def support() -> str:
    return _page("Screen Scout Support", f"""
<div class="card">
  <h1>Screen Scout Support</h1>
  <p class="soft">We're happy to help.</p>
  <p>{_contact_line()}</p>
</div>
<div class="card">
  <h2>Common questions</h2>
  <p><b>How do I add my partner?</b><br>Tap your profile, then <b>Send Invite</b>. They sign in
  and enter your code under <b>Join a family</b>.</p>
  <p><b>Why did a video fail?</b><br>Some videos are private, removed, or limited to certain
  countries or apps, so they can't be scouted.</p>
  <p><b>What happens when we hit the monthly limit?</b><br>New reviews pause until the first of
  next month. Opening videos you've already scouted is always free.</p>
  <p><b>How do I delete my account?</b><br>Tap your profile, then <b>Delete Account</b>.</p>
  <p><a href="/privacy">Privacy Policy</a></p>
</div>
""")
