# Design Decisions

## Thoughtful Date Plan MVP

The approved MVP design is recorded in `docs/superpowers/specs/2026-06-22-thoughtful-date-plan-mvp-design.md`.
The approved premium reveal app-flow refinement is recorded in `docs/superpowers/specs/2026-06-25-premium-reveal-app-flow-design.md`.

Key decisions:

- App name is Amora.
- Primary domain is `planwithamora.com`.
- Tagline is "Date plans with intention."
- Primary CTA is "Plan with Amora."
- Build a SwiftUI iOS app with a Cloudflare Worker backend.
- Keep the OpenAI API key server-side in the Worker.
- Use editable approximate area labels instead of raw coordinates in MVP generation requests.
- Prefer neighborhood-level planning areas when CoreLocation reverse geocoding provides them.
- Treat current-location detection as a convenience, not the primary planning input; typed location suggestions are the reliable path because simulator and device GPS can be broad or mocked.
- Use OpenAI web search for local venue relevance, but keep current event discovery out of scope.
- Gate exact venue details behind a StoreKit paywall.
- Make Amora Plus the primary paywall action and present the one-plan unlock as a lower-emphasis fallback, not an equal competing card.
- Show free anonymized previews that can regenerate before purchase.
- Use a schema-validated tool-call recovery pattern for backend plan generation.
- Use a two-step intake: first ask "What would make her feel seen?" with planning area, then collect vibe, budget, duration, and no-drinking constraints.
- Use one personal-anchor text field that accepts either a written summary or pasted chat/note context; screenshot and photo analysis are future extension points, not part of the current build.
- Show a simple intermediate loading screen while Amora generates the sealed preview, rather than leaving the user on the form with only a button spinner.
- Present the free preview as a sealed itinerary where each stop shows concept, vibe, reason, and personalization signal while hiding exact paid details.
- Show generated date cost estimates in the common local currency of the planning area; do not ask users to pick estimate currency in the MVP.
- Replace vague `$ / $$ / $$$` budget input with a local-currency stepped budget-for-two control; make clear Amora plans around the amount rather than trying to spend it all.
