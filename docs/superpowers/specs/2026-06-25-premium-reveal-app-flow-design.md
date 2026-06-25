# Premium Reveal App Flow Design

Date: 2026-06-25
Status: Approved for implementation planning

## Goal

Refine Amora's MVP flow so it feels more considerate, premium, and emotionally specific while keeping the product simple enough for the current app.

The new flow should make the user feel that Amora is listening before it configures logistics. The free preview should prove that a thoughtful itinerary exists without revealing the paid details.

The app should also make the user feel that the outcome he wants is more likely because he is showing up with a better plan. The product should create confidence that the date will feel smoother, more intentional, and more personal. It must not promise romantic results or imply that a plan can control another person's feelings.

## Product Direction

Use a two-step intake followed by a sealed itinerary preview.

The app should feel like a quiet planning brief, not a generic idea generator or a settings form. The emotional center of the flow is:

> What would make her feel seen?

Helper copy should make that prompt concrete:

> Tell us what she likes, notices, avoids, or has mentioned lately.

This keeps the screen emotionally resonant without becoming vague or overly sentimental.

The confidence message underneath the flow is:

> Your chances are better when the night feels considered.

This should guide tone, hierarchy, and paywall framing without becoming an explicit guarantee.

## Flow

### Step 1: Personal Anchor

The first screen asks what would make the date feel thoughtful for this person.

Required elements:

- Headline: "What would make her feel seen?"
- Helper text: "Tell us what she likes, notices, avoids, or paste a message or note you want us to consider."
- Multiline text field for the user's answer, pasted chat, or note context.
- Editable "Plan near" area label.
- Use current location action.
- Continue button.

The planning area belongs on this screen because it grounds the personal anchor in a real place without making logistics feel like the main event.

For the current implementation, do not add a separate context field. The same text field accepts either a clean summary from the user or pasted chat/note context. Screenshot upload, photo analysis, and separate extracted-signal confirmation should be designed as future extension points, but they are out of scope for the current build.

### Step 2: Shape The Night

The second screen collects constraints after the user has supplied the personal anchor.

Required elements:

- Vibe selection.
- Budget tier.
- Duration.
- No-drinking toggle.
- Back action to edit Step 1.
- Primary action to build the sealed preview.

The controls should be compact and tactile: chips or segmented controls where practical, and default form styling only where it remains the simplest correct choice.

### Preview: Sealed Itinerary

The free preview presents the plan as a sealed itinerary.

Each preview stop should answer three questions:

- What is the vibe?
- Why was this chosen?
- How does it connect to the personal details?

The preview may show:

- Plan title.
- Summary badges.
- Three stop concepts.
- Stop vibe.
- Short reason.
- Personalization signal.
- A clear unlock CTA.
- A free regenerate action.

The preview must hide:

- Exact venue names.
- Exact addresses.
- Apple Maps actions.
- Exact timing.
- Detailed cost estimates.

### Paywall: Reveal The Full Plan

The paywall should frame purchase as revealing a prepared itinerary, not buying random ideas.

The paywall should emphasize:

- More confidence going into the date.
- A smoother night with less guesswork.
- Exact venues.
- Timing per stop.
- Reasons tied to her interests.
- Estimated cost.
- Apple Maps actions.
- One exact-plan regenerate.

### Unlocked Plan

The unlocked plan continues to show exactly three stops.

Each unlocked stop includes:

- Venue name.
- Address or Apple Maps search query.
- Duration or timing per stop.
- Reason.
- Estimated cost range.
- Apple Maps action.

The unlocked screen should preserve the sense of a coherent itinerary, not become a list of unrelated venue cards.

## Data Model Impact

The current preview stop model only has `concept`. To support the approved preview, each preview stop needs fields equivalent to:

- `vibe`
- `reason`
- `personalizationSignal`

These fields should be returned by the backend and rendered in the iOS preview. The backend schema and tests should require exactly three preview stops and preserve the existing paid-detail boundary.

## Error Handling

Keep the existing MVP behavior:

- Failed location detection leaves the user able to enter the area manually.
- Failed generation shows a retryable error and does not unlock anything.
- Failed or cancelled purchase keeps the user on the preview.
- Successful purchase unlocks the current generated plan.

Step-level validation should be minimal:

- The user needs a non-empty planning area before generating.
- The personal prompt should be optional for technical purposes, but the UI should encourage it strongly.

## Testing

Implementation should verify:

- Step 1 can collect and retain personal detail and location.
- Step 2 can collect constraints and generate a preview.
- Back navigation preserves entered values.
- Preview renders the new stop vibe, reason, and personalization signal.
- The personal-anchor field accepts either a written summary or pasted chat/note context without requiring photo or screenshot upload.
- Purchase still unlocks the current plan.
- Regeneration still resets and preserves unlock behavior as intended.
- Backend schema accepts and returns the new preview fields.

## Out Of Scope

- Accounts.
- Saved partner profiles.
- Subscriptions.
- Map picker.
- Reservations or booking.
- Current event discovery.
- Screenshot or photo upload.
- More than three stops.
