# Activity-Biased Generation Design

Date: 2026-07-05
Status: Approved

## Summary

Amora should improve MVP generation so date plans do not over-default to parks, restaurants, bars, and coffee shops. The preview and unlocked plan are two views of the same generated itinerary, so activity variety must be handled in the backend generation contract rather than only in UI copy.

The MVP fix is a prompt-level generation refinement. It should bias toward activity-led stops when they fit the planning area, vibe, budget, duration, no-drinking constraint, and personal context. It should not add new intake controls, Google Places, event discovery, booking, or venue database work.

## Goals

- Make generated plans feel more thoughtful, specific, and less copy-pasted.
- Prioritize activities explicitly mentioned in the personal context field.
- Consider local activity-style stops by default when the user's inputs support them.
- Keep the MVP simple and within the current backend generation architecture.
- Preserve budget, duration, no-drinking, and local-area constraints.

## Non-Goals

- Add Google Places or another venue database.
- Add current event discovery.
- Add reservations, booking links, or availability checks.
- Add a new user-facing "activity date" intake control.
- Guarantee an activity stop in every plan.
- Build a venue taxonomy or post-generation category classifier for this refinement.

## Product Behavior

The backend prompt should instruct the model to consider activity-led stops as part of the normal planning process. Activity-led stops may include options such as axe throwing, bowling, pottery painting, mini golf, arcades, climbing, cooking classes, bookstores, galleries, museums, dance classes, markets, or similar local experiences.

Generation should prioritize activity signals in this order:

1. Activities explicitly mentioned in the personal context field.
2. Activities implied by the selected vibe, such as adventurous, playful, romantic, outdoorsy, cozy, low-key, or foodie.
3. Locally plausible activity options near the planning area when they fit budget and duration.

Food, drinks, coffee, parks, and walks may still appear when they are a good fit, especially as supporting stops. They should not become the default shape of most generated plans when an activity-led option would make the plan feel more personal or memorable.

No-drinking must continue to avoid alcohol-centered stops. Budget and duration remain hard planning constraints. The model should avoid forcing an activity when the area, budget, personal context, or timing makes it unrealistic.

## Architecture

This is a backend-only generation contract change in `worker/src/openai.ts`.

The existing `buildPrompt` function remains the right boundary because it already translates the request into model instructions for:

- Planning area.
- Budget.
- Vibe.
- Duration.
- No-drinking.
- Regeneration behavior.
- Personal context extraction.
- Preview and locked-plan schema requirements.

The refinement should add concise prompt instructions near the existing personalization and locality rules. No request schema changes are needed.

## Data Flow

The existing flow remains unchanged:

1. The iOS app sends the user's planning inputs to the Worker.
2. The Worker validates the request.
3. `buildPrompt` creates the generation prompt.
4. The OpenAI response is parsed and schema-validated.
5. The backend returns a preview plus the locked exact plan.

Because the preview and locked plan come from the same response, activity bias should affect both the anonymized preview concepts and the exact unlocked venues.

## Error Handling

No new runtime errors are introduced. The existing schema-validation and recovery loop remain responsible for invalid generation output.

The prompt should avoid absolute wording that would make valid plans impossible in sparse areas. Use "consider," "prefer," and "when realistic" instead of requiring an activity stop in every plan.

## Testing

Add or update Worker tests around `buildPrompt` to verify the prompt includes:

- A rule to prioritize activities mentioned in personal context.
- A rule to consider activity-led local stops when supported by vibe, area, budget, and duration.
- A rule that food, drinks, coffee, parks, and walks should not be the default shape of most plans.
- A rule that activities should not be forced when unrealistic.

No iOS tests are needed because the UI and API shape do not change.

## Success Criteria

- Backend prompt tests pass.
- No request or response schema changes are made.
- Preview and unlocked plan generation are both covered by the same activity-biased instructions.
- The documented MVP scope remains clear: improve plan variety without adding live venue integrations.
