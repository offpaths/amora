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
- Use OpenAI web search for local venue relevance, but keep current event discovery out of scope.
- Gate exact venue details behind a StoreKit consumable paywall.
- Show free anonymized previews that can regenerate before purchase.
- Use a schema-validated tool-call recovery pattern for backend plan generation.
- Use a two-step intake: first ask "What would make her feel seen?" with planning area, then collect vibe, budget, duration, and no-drinking constraints.
- Present the free preview as a sealed itinerary where each stop shows concept, vibe, reason, and personalization signal while hiding exact paid details.
