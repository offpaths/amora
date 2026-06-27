# Budget for Two Slider Design

Date: 2026-06-27
Status: Approved

## Context

The existing budget input uses `$`, `$$`, and `$$$`. That is compact, but too vague for the target user because it does not explain whether the user is choosing total spend, venue category, or how impressive the date should feel.

The product should avoid implying that a more expensive date is a better or more thoughtful date. Amora's value is planning with intention inside the user's practical comfort level.

## Decision

Replace the symbolic budget tier with a concrete local-currency budget control for the full date for two people.

The control should show a selected amount in the common local currency resolved from the planning country. The selected amount is a planning constraint and comfort signal, not a target to exhaust.

Recommended label:

`Budget for two`

Recommended helper copy:

`Amora will plan around this amount, not spend it for the sake of it.`

## Interaction Model

Use a stepped slider or similarly direct stepped control rather than a free-form numeric field. Steps should be easy to scan and should avoid false precision.

Example US steps:

- `USD 50`
- `USD 100`
- `USD 150`
- `USD 200`
- `USD 300+`

The app should choose equivalent-feeling steps for other currencies, such as `GBP`, `EUR`, or `THB`, using the planning area's resolved country.

## Product Guidance

Lower budget selections must still produce thoughtful plans. They should bias toward simple, personal, and low-cost moments rather than feeling like downgraded plans.

Higher budget selections may allow one elevated paid anchor when it fits the user's preferences, but should not fill the plan with expensive stops just because the budget allows it.

## Implementation Notes

The existing local-currency resolution used for generated plan cost estimates should also drive the displayed budget currency.

The backend prompt should receive a concrete budget amount or budget band rather than only symbolic `$ / $$ / $$$`, so generated plans can stay near the user's practical spend comfort.

Existing cost estimate behavior remains unchanged: generated estimates are approximate ranges for two people in the common local currency of the planning area.

## Verification

Success means a user can understand the budget input without interpreting symbols and without feeling that higher spend equals a better date.

Testable outcomes:

- The input screen shows a local-currency budget for two people.
- The helper copy says Amora plans around the amount rather than trying to spend it all.
- Generated requests preserve enough budget information for the backend to plan within the selected spend comfort.
- Low-budget selections can still produce intentional, premium-feeling plans.
