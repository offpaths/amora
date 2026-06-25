# Project Notes

## Product Decisions

- The Thursday MVP is a premium thoughtful date-plan assistant, not a cheap infinite date-ideas library.
- The core promise is: "Tell us what would make this feel personal. We will build a thoughtful 3-stop date plan near you."
- The MVP uses an anonymized free preview, a primary StoreKit subscription unlock, and a secondary StoreKit consumable unlock for the exact plan.
- The first subscription tier is "Amora Plus" with product id `amora_plus_monthly`, target price $9.99/month, and unlimited unlocked thoughtful date plans.
- The first paid product is "Unlock 1 Thoughtful Date Plan" with a target price of $4.99.
- The first paid product id is `thoughtful_date_plan_unlock_1`.
- Strategic monetization is subscription-first, with one-plan unlock as a lower-friction fallback.
- Date-plan cost estimates should use the common local currency of the planning area, while App Store purchase currency remains StoreKit/storefront-managed.
- Product and marketing should warn against recycled/copy-pasted dates by making personalization the value.
- Current event discovery, Google Places, saved profiles, and accounts are out of scope for the MVP.
