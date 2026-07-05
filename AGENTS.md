# Project Notes

## Product Decisions

- The Thursday MVP is a premium thoughtful date-plan assistant, not a cheap infinite date-ideas library.
- The core promise is: "Tell us what would make this feel personal. We will build a thoughtful 3-stop date plan near you."
- The MVP uses an anonymized free preview and a StoreKit subscription unlock.
- The first subscription tier is "Amora Plus" with product id `amora_plus_monthly`, target price $9.99/month, and unlimited unlocked thoughtful date plans.
- Strategic monetization is subscription-only for launch to keep purchase restore and support expectations clean.
- Date-plan cost estimates should use the common local currency of the planning area, while App Store purchase currency remains StoreKit/storefront-managed.
- Budget input should be a practical local-currency spend comfort for the full date for two people, not a date-quality or impressiveness ladder.
- Typed planning-area suggestions should stay lightweight and optional; do not force map/radius selection in the MVP.
- Product and marketing should warn against recycled/copy-pasted dates by making personalization the value.
- AI data-use consent should appear as a one-time screen immediately after the opening loading screen and before the intake form, with reassuring copy that the shared context is used to make a thoughtful, specific plan.
- Amora does not collect in-app analytics or telemetry for the MVP; rely on App Store Connect for app performance, purchase, and subscription reporting.
- Current event discovery, Google Places, saved profiles, and accounts are out of scope for the MVP.
- Intake defaults should allow drinking; users opt into the no-drinking constraint when needed.
- The app saves the latest fully unlocked plan on-device for convenience; this does not promise recovery after app deletion or device changes.
- Backend generation requests use Durable Object rate limiting to protect OpenAI spend across Worker isolates and restarts.
- The Worker must reject oversized generation requests before parsing JSON, and must not log request bodies, prompts, OpenAI responses, or generated plans.
- `OPENAI_API_KEY` must be configured with `wrangler secret put OPENAI_API_KEY` and never committed in source or Wrangler config.
- Paid plan unlocks use only an opaque `planToken` and Apple's signed StoreKit transaction proof; purchaser profile fields must not be sent to the backend.
- MVP generation should bias toward activity-led date stops when supported by the planning area, vibe, budget, duration, and personal context; restaurants, bars, coffee shops, parks, and walks should not become the default shape of most plans.
