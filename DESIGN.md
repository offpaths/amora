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
- Make Amora Plus the paywall action for unlocking exact plan details.
- Show free anonymized previews that can regenerate before purchase.
- Use a schema-validated tool-call recovery pattern for backend plan generation.
- Use a two-step intake: first ask "What would make her feel seen?" with planning area, then collect vibe, budget, duration, and no-drinking constraints.
- Use one personal-anchor text field that accepts either a written summary or pasted chat/note context; screenshot and photo analysis are future extension points, not part of the current build.
- Show a simple intermediate loading screen while Amora generates the sealed preview, rather than leaving the user on the form with only a button spinner.
- Present the free preview as a sealed itinerary where each stop shows concept, vibe, reason, and personalization signal while hiding exact paid details.
- Show generated date cost estimates in the common local currency of the planning area; do not ask users to pick estimate currency in the MVP.
- Replace vague `$ / $$ / $$$` budget input with a local-currency stepped budget-for-two control; make clear Amora plans around the amount rather than trying to spend it all.
- When a saved unlocked plan exists, the first intake step shows a compact previous-plan card that opens the latest unlocked plan saved on this device.

## Visual System

DESIGN.md is the source of truth for app colors, visual styling, and reusable interface decisions. SwiftUI theme constants should implement the choices documented here.

Palette:

- Background: warm ivory, `#F7F2E9`, SwiftUI RGB `0.969, 0.949, 0.914`.
- Surface: soft paper, `#FFFDF8`, SwiftUI RGB `1.000, 0.992, 0.973`.
- Ink: near-black brown, `#211A17`, SwiftUI RGB `0.129, 0.102, 0.090`.
- Muted text: warm gray-brown, `#746B63`, SwiftUI RGB `0.455, 0.420, 0.388`.
- Accent / oxblood: deep romantic red, `#6E1F2B`, SwiftUI RGB `0.431, 0.122, 0.169`.
- Brass: muted gold-brown, `#795720`, SwiftUI RGB `0.475, 0.341, 0.125`.
- Olive: grounded green, `#536B4E`, SwiftUI RGB `0.325, 0.420, 0.306`.
- Border: warm hairline beige, `#E3D8CA`, SwiftUI RGB `0.890, 0.847, 0.792`.

Brand color usage:

- The word "Amora" should appear in the accent / oxblood color when it appears as visible brand copy in app UI.
- Primary actions, progress indicators, key icons, links, and error text use the accent / oxblood color.
- Use brass and olive as secondary supporting accents for badges, costs, and illustrative details.

Reusable component styling:

- Screens use the warm ivory background and near-black brown default text.
- Cards use the soft paper surface, 18pt padding, 8pt corner radius, and a 1pt warm beige border.
- Primary buttons use the oxblood background, soft paper text, 8pt corner radius, and reduced opacity when loading or disabled.
- Secondary buttons use the soft paper background, ink text, 8pt corner radius, and a warm beige border.
- Pills use semibold caption text, tinted text, a 10% tint background, and a 24% tint border.
- Itinerary numbers are 28pt circles with ink fill and surface-colored number text.
- Stop illustration panels use brass wash backgrounds, oxblood primary icons, and olive secondary accents.
