# Design Decisions

## Thoughtful Date Plan MVP

The approved MVP design is recorded in `docs/superpowers/specs/2026-06-22-thoughtful-date-plan-mvp-design.md`.

Key decisions:

- Build a SwiftUI iOS app with a Cloudflare Worker backend.
- Keep the OpenAI API key server-side in the Worker.
- Use approximate location labels instead of raw coordinates in MVP generation requests.
- Use OpenAI web search for local venue relevance, but keep current event discovery out of scope.
- Gate exact venue details behind a StoreKit consumable paywall.
- Show free anonymized previews that can regenerate before purchase.
- Use a schema-validated tool-call recovery pattern for backend plan generation.
