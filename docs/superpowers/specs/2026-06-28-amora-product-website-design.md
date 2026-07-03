# Amora Product Website Design

Date: 2026-06-28
Status: Approved

## Goal

Create a public website for Amora at `planwithamora.com` that explains the product, publishes the legal/support pages required for App Review, and gives reviewers or collaborators one place to reference the app's product behavior, purchase products, data-use limits, and test flow.

## Assumptions

- The website will be a simple static site in a new `website/` folder.
- The site will use the existing Amora brand decisions from `PRD.md`, `MARKETING.md`, `DESIGN.md`, `AGENTS.md`, and `docs/legal/*`.
- The site will not add new product claims beyond the current MVP.
- The site will not require a framework, account system, backend calls, or app download integration.
- The app is not yet represented as a live App Store listing in this repo, so calls to action should use product language rather than fake App Store links.

## Information Architecture

The website will include these pages:

- `index.html`: Public product page with the primary pitch, product flow, pricing, privacy summary, and launch/reference details.
- `privacy.html`: Public privacy policy using the current privacy draft.
- `terms.html`: Public terms of use using the current terms draft.
- `support.html`: Public support page using the current support draft.
- `reference.html`: App/reference page with implementation facts that App Review, collaborators, or deployment work may need.

The header and footer will link all pages. The public App Review URLs map to:

- `https://planwithamora.com/privacy`
- `https://planwithamora.com/terms`
- `https://planwithamora.com/support`

For local static files, those pages will exist as `.html` files. Deployment can route extensionless paths later.

## Content Requirements

The home page must include:

- Brand: Amora.
- Tagline: "Date plans with intention."
- Primary promise: "Plan a date that makes her feel seen."
- Supporting promise: "Tell us what would make this feel personal. We will build a thoughtful 3-stop date plan near you."
- Explanation of the preview/unlock flow.
- Pricing and StoreKit product references:
  - Amora Plus Monthly, product id `amora_plus_monthly`, target price `$9.99/month`.
- Data-use summary:
  - Planning area, preferences, budget, duration, no-drinking preference, and personal context may be sent to the AI provider to generate a plan.
  - Location detection is optional and users can type a planning area.
  - The MVP sends area labels, not raw coordinates.
  - Amora does not collect in-app analytics; app performance, purchase, and subscription reporting come from App Store Connect.
- Clear links to privacy, terms, support, and reference pages.

The reference page must include:

- Product overview and current MVP scope.
- Required backend URL: `https://api.planwithamora.com`.
- StoreKit product ID and unlock behavior.
- Reviewer test flow.
- Preview content shown and hidden.
- Unlocked plan content.
- Non-goals: no accounts, no saved profiles, no reservations, no current-event discovery, no Google Places integration.
- Support and legal URL references.

## Visual Design

Use the established Amora visual system:

- Warm ivory background: `#F7F2E9`.
- Soft paper surface: `#FFFDF8`.
- Ink text: `#211A17`.
- Muted text: `#746B63`.
- Accent oxblood: `#6E1F2B`.
- Brass: `#795720`.
- Olive: `#536B4E`.
- Border: `#E3D8CA`.

The site should feel like a premium thoughtful planning tool rather than a generic AI landing page. Use restrained sections, clear typography, useful product details, and a small static product preview instead of heavy animation or decorative complexity.

Cards may be used for specific repeated items or reference panels, with 8px border radius to match the app decision. Avoid nested cards and marketing filler.

## Implementation Shape

Create:

- `website/index.html`
- `website/privacy.html`
- `website/terms.html`
- `website/support.html`
- `website/reference.html`
- `website/styles.css`
- `website/favicon.svg`
- `website/README.md`

All pages will share the same stylesheet. HTML should be semantic and readable. The site should work by opening `website/index.html` directly and through a simple static server.

## Verification

Success means:

- All expected pages exist and link to each other.
- The home page includes the product promise, preview/unlock behavior, pricing, data-use summary, and reference links.
- Legal/support pages publish the required App Review content.
- The reference page contains reviewer/deployment/product facts from the app docs.
- Local static serving works.
- HTML and links pass a lightweight local verification script or equivalent command.
- Desktop and mobile browser screenshots show no obvious overflow or broken layout.
