# Thoughtful Date Plan MVP Design

Date: 2026-06-22
Status: Approved for planning

## Goal

Build a Thursday MVP for a premium iOS app that generates a thoughtful 3-stop date plan near the user. The app should help someone plan a date that feels personal, intentional, and tailored to what the other person likes.

The MVP tests whether users will pay to unlock a specific, high-quality date plan.

## Positioning

The product is not an infinite library of cheap date ideas. It is a premium planning assistant for someone who wants to make the other person feel seen.

Core promise:

> Tell us what she likes. We will build a thoughtful 3-stop date plan near you.

Copy should emphasize confidence, care, and thoughtfulness. It should not imply manipulation or guaranteed romantic outcomes.

Example copy:

- Plan a date that feels personal.
- Built around what she likes, your budget, and places nearby.
- Show her you actually thought this through.

## Platform Stack

### iOS App

- Swift
- SwiftUI
- CoreLocation for current location
- CLGeocoder for editable approximate area labels
- MapKit / Apple Maps URLs for directions
- StoreKit for in-app purchase
- URLSession for backend calls

### Backend

- Cloudflare Worker in TypeScript
- OpenAI Responses API with web search
- Server-side `OPENAI_API_KEY`
- One narrow generation endpoint

## User Inputs

The input screen collects:

- Current location with editable "Plan near" area
- Budget tier: `$`, `$$`, `$$$`
- Vibe chip: cozy, adventurous, romantic, low-key, foodie, outdoorsy
- No drinking toggle
- Date duration: 1.5 hours, 2 hours, 3 hours, 4 hours
- Optional free-text field: "What does she like?"

If current location is allowed, the app reverse-geocodes it into the most specific friendly area label available. Prefer neighborhood-level values from `subLocality` when available, then city-level values from `locality`, then broader region values as a fallback.

The input screen shows the detected area in an editable "Plan near" field, such as "Williamsburg, Brooklyn", "SoHo", "near Central Park", or "Austin, TX". If current location is denied or unavailable, the same field becomes the manual city/neighborhood fallback.

The app sends only this editable approximate area label to the backend. It does not send raw latitude/longitude in the MVP.

## Generated Plan

The backend returns a plan with exactly 3 stops.

Each unlocked stop includes:

- Venue name
- Address or Apple Maps search query
- Time per stop
- Short reason
- Estimated cost
- Apple Maps action data

The full plan also includes:

- Total estimated cost
- Total duration
- Budget tier
- Vibe
- No-drinking confirmation when applicable
- Brief explanation of how the plan uses the supplied interests

Estimated costs are approximate and should be presented as ranges, not guarantees.

## Preview And Paywall

The free experience shows an anonymized preview, not the exact venue names.

The preview shows:

- 3 anonymized stop concepts
- Matched-interest badges
- Budget, duration, and no-drinking summary
- A short teaser explaining why the plan fits

Example preview stops:

- A cozy conversation starter near Downtown
- A personal activity matched to her love of bookstores
- A low-pressure dessert finish

The preview must not reveal:

- Exact venue names
- Exact addresses
- Apple Maps links
- Full timing
- Full reasons
- Detailed cost estimate

Free users can regenerate previews before purchase.

## Monetization

The MVP uses one StoreKit consumable product:

- Product: Unlock 1 Thoughtful Date Plan
- Product id: `thoughtful_date_plan_unlock_1`
- Target price: $4.99

Purchasing unlocks the current generated plan.

The unlocked plan reveals:

- Exact venue names
- Time per stop
- Short reasons
- Estimated cost
- Apple Maps buttons
- 1 exact-plan regenerate

No subscription is included in the Thursday MVP.

Unlock state is stored locally on-device for the MVP. Accounts and cross-device restore are out of scope.

## User Flow

1. User opens the app and enters date-planning inputs.
2. App requests current location.
3. App reverse-geocodes the location into the most specific friendly area label available.
4. App shows the area in an editable "Plan near" field.
5. App sends inputs to the Cloudflare Worker.
6. Worker generates both an anonymized preview and locked exact plan.
7. App shows the preview.
8. User can regenerate previews for free.
9. User taps unlock.
10. StoreKit presents the purchase flow for Unlock 1 Thoughtful Date Plan.
11. Successful purchase unlocks the exact plan locally.
12. User can open each stop in Apple Maps.
13. User gets one exact-plan regenerate after unlock.

## Backend API

### `POST /generate-plan`

Request body:

```json
{
  "locationLabel": "Williamsburg, Brooklyn",
  "budgetTier": "$$",
  "vibe": "cozy",
  "noDrinking": true,
  "durationMinutes": 120,
  "partnerLikes": "bookstores, matcha, quiet places"
}
```

Response body:

```json
{
  "id": "generated-plan-id",
  "preview": {
    "title": "A cozy 2-hour plan near Williamsburg",
    "summaryBadges": ["$$", "2 hours", "No bars", "Matched to bookstores"],
    "stops": [
      {
        "order": 1,
        "concept": "A cozy conversation starter near Williamsburg"
      },
      {
        "order": 2,
        "concept": "A personal activity matched to her love of bookstores"
      },
      {
        "order": 3,
        "concept": "A relaxed dessert finish nearby"
      }
    ]
  },
  "lockedPlan": {
    "totalEstimatedCost": "$60-$90",
    "stops": [
      {
        "order": 1,
        "venueName": "Example Cafe",
        "address": "123 Example St",
        "appleMapsQuery": "Example Cafe 123 Example St",
        "durationMinutes": 35,
        "reason": "A calm first stop that fits the cozy vibe.",
        "estimatedCost": "$20-$30"
      },
      {
        "order": 2,
        "venueName": "Example Bookstore",
        "address": "456 Example Ave",
        "appleMapsQuery": "Example Bookstore 456 Example Ave",
        "durationMinutes": 50,
        "reason": "A personal stop aligned with her interest in bookstores.",
        "estimatedCost": "$10-$25"
      },
      {
        "order": 3,
        "venueName": "Example Dessert Bar",
        "address": "789 Example Rd",
        "appleMapsQuery": "Example Dessert Bar 789 Example Rd",
        "durationMinutes": 35,
        "reason": "A relaxed finish that keeps the date low-pressure.",
        "estimatedCost": "$30-$35"
      }
    ]
  }
}
```

The final schema must require exactly 3 preview stops and exactly 3 locked stops.

The generation prompt must treat `locationLabel` as the planning area, not the entire metro region. It should prefer stops that are close to that area and close enough to each other for a short walk or short rideshare. The MVP does not include a map picker, custom radius, or full route optimization.

## OpenAI Reliability Pattern

The Worker avoids relying on raw JSON text for the final plan response.

The intended implementation is a schema-validated tool-call recovery pattern:

1. Define a plan schema in the Worker.
2. Expose a `createDatePlan` tool whose input schema matches the plan response.
3. Ask the model to call `createDatePlan` with the final plan.
4. Validate tool arguments at the boundary.
5. Allow up to 5 model steps so the model can self-correct after validation errors.
6. If no valid plan is produced, return a clean retryable error.

This replaces the simpler "retry malformed JSON once" behavior. A failed generation must not charge the user or unlock a plan.

## Error Handling

- If location permission is denied, show manual city/neighborhood input.
- If reverse geocoding fails, use the nearest city/region label if available.
- If the detected area looks too broad, the user can edit the "Plan near" field before generation.
- If the Worker fails, show a retry state without charging.
- If OpenAI cannot produce a valid schema after the recovery loop, return a retryable error.
- If purchase fails or is cancelled, keep the user on the locked preview.
- If purchase succeeds, unlock the current plan locally.
- If Apple Maps cannot open natively, fall back to an Apple Maps web URL.

## Out Of Scope

- Current event discovery
- Google Places API
- Saved partner profiles
- Accounts or login
- Cross-device unlock restore
- Subscriptions
- Payment outside StoreKit
- Reservations or booking
- Exact price guarantees
- Full route optimization
- Social sharing

## Verification

Automated checks:

- Swift tests for request payload building.
- Swift tests for plan parsing.
- Worker tests for request validation.
- Worker tests for response schema shape.
- Worker tests for invalid model output recovery path.

Manual checks:

- Location permission happy path.
- Neighborhood-level "Plan near" field is populated when reverse geocoding provides it.
- User can edit the "Plan near" field before generation.
- Denied-location fallback.
- Generate preview.
- Preview regenerate.
- StoreKit sandbox purchase.
- Full plan unlock.
- One exact-plan regenerate after unlock.
- Apple Maps action opens for each stop.
- OpenAI API key is absent from the iOS app.

## Success Criteria

- User can generate an anonymized preview from current, edited, or typed location area.
- Preview proves relevance without leaking exact venue names.
- User can pay $4.99 through StoreKit to unlock the exact plan.
- Unlocked plan includes 3 stops, timing, reasons, estimated cost, and Apple Maps actions.
- Paid user gets one exact-plan regenerate.
- Failed generation or failed purchase never charges or unlocks.
- OpenAI API key is stored only in the Cloudflare Worker environment.
