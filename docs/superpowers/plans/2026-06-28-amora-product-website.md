# Amora Product Website Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a static Amora product website that publishes the public product, legal, support, and app-reference information needed for the MVP.

**Architecture:** Add a standalone static site in `website/` so the iOS app and worker remain untouched. Use one shared stylesheet, semantic HTML pages, and local verification with a static server plus link/content checks.

**Tech Stack:** Static HTML, CSS, shell verification, local static serving with Python's built-in HTTP server.

---

### Task 1: Create Static Site Files

**Files:**
- Create: `website/index.html`
- Create: `website/privacy.html`
- Create: `website/terms.html`
- Create: `website/support.html`
- Create: `website/reference.html`
- Create: `website/styles.css`
- Create: `website/favicon.svg`
- Create: `website/README.md`

- [ ] **Step 1: Add the shared stylesheet**

Create `website/styles.css` with Amora colors, responsive layout rules, button/link states, reference panels, and mobile-safe typography.

- [ ] **Step 2: Add the home page**

Create `website/index.html` with the hero, product promise, flow, pricing, data-use summary, launch checklist, and footer links.

- [ ] **Step 3: Add legal and support pages**

Create `website/privacy.html`, `website/terms.html`, and `website/support.html` using the current drafts in `docs/legal/`.

- [ ] **Step 4: Add the reference page**

Create `website/reference.html` with product facts from `PRD.md`, `MARKETING.md`, `DESIGN.md`, `AGENTS.md`, and `docs/app-review-notes.md`.

- [ ] **Step 5: Add usage notes**

Create `website/README.md` with local preview commands and deployment notes for extensionless production routing.

### Task 2: Verify Static Content

**Files:**
- Read: `website/*.html`
- Read: `website/styles.css`

- [ ] **Step 1: Check required files exist**

Run:

```bash
test -f website/index.html && test -f website/privacy.html && test -f website/terms.html && test -f website/support.html && test -f website/reference.html && test -f website/styles.css && test -f website/favicon.svg && test -f website/README.md
```

Expected: command exits with status 0.

- [ ] **Step 2: Check required product references**

Run:

```bash
rg "amora_plus_monthly|api.planwithamora.com|Plan a date that makes her feel seen|support@planwithamora.com" website
```

Expected: all required strings appear in the website files.

- [ ] **Step 3: Start a local static server**

Run:

```bash
python3 -m http.server 4173 --directory website
```

Expected: server starts and serves pages at `http://127.0.0.1:4173/`.

- [ ] **Step 4: Fetch key pages**

Run:

```bash
curl -I http://127.0.0.1:4173/
curl -I http://127.0.0.1:4173/privacy.html
curl -I http://127.0.0.1:4173/terms.html
curl -I http://127.0.0.1:4173/support.html
curl -I http://127.0.0.1:4173/reference.html
```

Expected: each request returns `HTTP/1.0 200 OK` or `HTTP/1.1 200 OK`.

### Task 3: Browser QA

**Files:**
- Inspect: `website/index.html`
- Inspect: `website/reference.html`

- [ ] **Step 1: Open local site in a browser**

Open `http://127.0.0.1:4173/` and inspect the home page.

- [ ] **Step 2: Verify desktop layout**

Check that the hero, preview mockup, pricing panels, privacy summary, and footer links are readable without overlap.

- [ ] **Step 3: Verify mobile layout**

Check a mobile-sized viewport and confirm navigation wraps cleanly, text stays inside containers, and the reference panels remain readable.

- [ ] **Step 4: Verify navigation**

Click links for Home, Privacy, Terms, Support, and Reference. Each should load the intended page.

### Task 4: Completion Audit

**Files:**
- Read: `docs/superpowers/specs/2026-06-28-amora-product-website-design.md`
- Read: `website/*`

- [ ] **Step 1: Compare implementation against design spec**

Confirm each requirement in the design spec is present in the website.

- [ ] **Step 2: Check worktree scope**

Run:

```bash
git status --short
```

Expected: changes are limited to the new design/plan docs and `website/` files.
