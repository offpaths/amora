# PRD: Thoughtful Date Plan MVP

Date: 2026-06-22
Status: Draft

## Summary

Build Amora, a premium iOS MVP that helps a user create a thoughtful 3-stop date plan near a chosen area. The app asks for lightweight context, generates an anonymized preview, and charges to unlock the exact plan.

The MVP tests whether users will subscribe for specific, personalized date planning. Launch monetization is subscription-only to keep purchase restore and support expectations clean.

## Brand

- App name: Amora.
- Domain: `planwithamora.com`.
- Tagline: Date plans with intention.
- Primary CTA: Plan with Amora.

Brand rationale:

- Amora is one word, soft, romantic, elegant, and memorable.
- `planwithamora.com` clarifies the product action while keeping the app name simple.
- The brand should feel like a quiet planning tool, not a separate person taking credit for the date.

Copy watchout:

- Prefer "planned with Amora" or "plan with Amora."
- Avoid "Amora helped him plan this" because it can sound like another woman helped him.

## Target User

Primary user:

- Single men, roughly 24-38.
- Already have a date or are trying to plan one.
- Want to seem thoughtful without spending hours researching.
- Feel planning anxiety and want confidence that the date will feel intentional.

MVP audience scope:

- Marketing focuses on men planning dates for women.
- This is a go-to-market constraint, not a permanent product limitation.
- Product and data language should stay gender-neutral where practical.

Secondary future user:

- Men in relationships who want help planning better date nights.

The MVP should serve both, but marketing and product focus start with single men.

## Problem

Planning a good date takes effort, local research, and taste. Many users default to asking "what do you want to do?" or choosing generic dinner/drinks because they do not know how to translate what someone likes into an actual plan.

The user needs a fast way to create a plan that feels personal, realistic, and nearby.

## Product Promise

Primary promise:

> Plan a date that makes her feel seen.

Supporting promise:

> Tell us what would make this feel personal. We will build a thoughtful 3-stop date plan near you.

The product should feel premium and intentional, not like a cheap infinite date-idea generator.

Secondary conversion angle:

> Make the money you are already spending on the date worth it by planning something that helps her feel seen and shows that you care.

Freshness angle:

> The best dates do not feel copy-pasted. Build something around this person, this week, and this mood.

## MVP Goals

- Let the user generate an anonymized date-plan preview from a small set of inputs.
- Prove relevance before purchase without leaking exact venue details.
- Let the user start Amora Plus to unlock the exact 3-stop plan.
- Show timing, reasons, cost estimate, and Apple Maps actions after unlock.
- Keep the OpenAI API key out of the iOS app.
- Keep location precise enough to be useful without adding a map picker or radius controls.

## Non-Goals

- Current event discovery.
- Google Places API.
- Saved partner profiles.
- Accounts or login.
- Cross-device purchase restore beyond StoreKit basics.
- Reservations or booking.
- Exact price guarantees.
- Full route optimization.
- Social sharing.
- Separate women-facing product experience.

## User Inputs

The input screen collects:

- Current location with editable "Plan near" area.
- Budget tier: `$`, `$$`, `$$$`.
- Vibe chip: cozy, adventurous, romantic, low-key, foodie, outdoorsy.
- No drinking toggle.
- Date duration: 1.5 hours, 2 hours, 3 hours, 4 hours.
- Optional free-text field: "What would make this feel personal?"

Location behavior:

- Use CoreLocation to get current location.
- Use CLGeocoder to produce the most specific friendly area label available.
- Prefer neighborhood-level labels when available.
- Show the detected area in an editable "Plan near" field.
- If location permission is denied or unavailable, use the same field as manual city/neighborhood input.
- Send only the editable area label to the backend, not raw latitude/longitude.

## Core User Flow

1. User opens the app.
2. User enters inputs.
3. App detects and displays an editable "Plan near" area.
4. User generates a plan preview.
5. App shows anonymized preview concepts.
6. User can regenerate previews for free.
7. User taps unlock.
8. StoreKit presents Amora Plus as the subscription offer.
9. Purchase succeeds.
10. App reveals exact venue names, timing, reasons, cost estimates, and Apple Maps actions.
11. Active Amora Plus members can regenerate unlocked plans.

## Preview Requirements

The free preview must show enough specificity to build trust.

Preview shows:

- Anonymized 3-stop concepts.
- Matched-interest signals.
- A personal-touch signal that shows the plan was built around supplied details.
- Budget, duration, and no-drinking badges.
- Short teaser explaining why the plan fits.

Preview hides:

- Exact venue names.
- Exact addresses.
- Full timing.
- Full reasons.
- Detailed cost estimate.
- Apple Maps actions.

## Unlocked Plan Requirements

The unlocked plan includes exactly 3 stops.

Each stop includes:

- Venue name.
- Address or Apple Maps search query.
- Time per stop.
- Short reason.
- Estimated cost range.
- Apple Maps action.

The full plan includes:

- Total estimated cost range.
- Total duration.
- Budget tier.
- Vibe.
- No-drinking confirmation when applicable.
- Brief explanation of how the plan uses supplied interests.

## Monetization

- Subscription-first positioning.
- Monthly subscription is the primary offer because users need fresh plans for different people, moods, and moments.
- Launch monetization is subscription-only to keep restore and support expectations clean.

Current implemented MVP product:

- Primary StoreKit auto-renewable subscription.
- Name: Amora Plus.
- Product id: `amora_plus_monthly`.
- Target price: $9.99/month.
- Value: unlimited unlocked thoughtful date plans.

Purchase behavior:

- Active Amora Plus subscription unlocks generated plans and allows unlimited regeneration while active.
- Failed generation or failed purchase must not charge or unlock.

## Backend Requirements

Use a tiny Cloudflare Worker backend.

Worker responsibilities:

- Receive generation inputs.
- Validate request body.
- Store and use `OPENAI_API_KEY` server-side.
- Call OpenAI Responses API with web search.
- Return strict structured JSON.
- Avoid raw JSON text for final plan output where feasible.

Generation constraints:

- The prompt treats `locationLabel` as the planning area, not the whole metro region.
- Prefer stops close to the planning area.
- Prefer stops close enough to each other for a short walk or short rideshare.
- Make the plan feel specific to the supplied personal details, not like a reusable generic route.
- Use supplied interests in preview concepts and locked-stop reasons when provided.
- Avoid plans that could be copy-pasted for different people without changing the personal logic.
- Estimate costs for two people in the common local currency of the planning area, using broad approximate ranges.
- Do not promise current events.

Reliability pattern:

- Use a schema-validated tool-call recovery loop.
- Allow up to 5 model steps for self-correction after validation errors.
- Return a clean retryable error if no valid plan is produced.

## Error Handling

- Location denied: show manual city/neighborhood input.
- Reverse geocoding fails: use nearest city/region label if available.
- Detected area too broad: user can edit "Plan near" before generation.
- Worker fails: show retry state without charging.
- OpenAI validation fails: show retry state without charging.
- Purchase cancelled: keep locked preview.
- Purchase succeeds: unlock current plan locally.
- Apple Maps unavailable: fall back to Apple Maps web URL.

## Marketing Direction

Primary marketing audience:

- Single men planning early dates.

Primary channel:

- Women dating-advice creators who speak to men.

Women can also be marketed to as the sharing channel:

> If he says he wants to plan something but does not know what to do, send him this.

The MVP does not need separate product flows for women. It only needs clear marketing copy and a shareable concept later.

## Success Metrics

MVP validation metrics:

- Preview generation completion rate.
- Preview regenerate rate.
- Paywall view rate.
- Purchase conversion rate.
- Purchase cancellation rate.
- Exact-plan regenerate rate.
- Apple Maps tap rate.
- Generation failure rate.

Initial product success means users understand the preview, trust the plan enough to unlock, and use Apple Maps actions after purchase.

The subscription story should frame recurring value as fresh plans for different people, moods, and moments so users do not recycle the same date.

## Acceptance Criteria

- User can generate an anonymized preview from current, edited, or typed location area.
- Preview does not reveal exact venue names or addresses.
- User can unlock the exact plan through StoreKit.
- Unlocked plan includes exactly 3 stops.
- Each unlocked stop includes timing, reason, estimated cost, and Apple Maps action.
- Paid user gets 1 exact-plan regenerate.
- Backend keeps OpenAI API key out of the iOS app.
- Worker returns clean retryable errors for invalid generation output.
- Current events, Google Places, accounts, subscription purchase flow, and route optimization are not implemented.

## Reference Docs

- `docs/superpowers/specs/2026-06-22-thoughtful-date-plan-mvp-design.md`
- `DESIGN.md`
- `MARKETING.md`
