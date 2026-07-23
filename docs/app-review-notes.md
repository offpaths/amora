# App Review Notes

Amora is a personalized date-plan assistant that generates a free anonymized preview and offers an Amora Plus StoreKit subscription for exact venue details.

Required public support links:

- Privacy Policy: https://planwithamora.com/privacy
- Terms of Use: https://planwithamora.com/terms
- Support: https://planwithamora.com/support

If no site deployment exists in this repo, publish these pages outside this repo before App Review. Do not submit placeholder or unpublished legal/support URLs.

Reviewer notes:

- No account or login is required.
- The production backend must be live at `https://api.planwithamora.com`.
- Before generation, the app shows an AI disclosure explaining that planning area, preferences, and personal context are sent to the AI provider to generate the result.
- Amora uses privacy-limited PostHog Cloud EU product analytics for selected planning and subscription funnel events. Analytics use a random, pseudonymous installation identifier and standard technical metadata; they exclude user-entered text, generated plans, planning area or location, Apple transaction identifiers, and payment proof. GeoIP enrichment, error autocapture, person profiles, session replay, advertising identifiers, and cross-app tracking are disabled or not used. App Store Connect remains authoritative for app performance, purchases, and subscriptions.
- In-app purchases use StoreKit products managed by App Store Connect.
- Amora Plus Monthly (`amora_plus_monthly`) unlocks unlimited thoughtful date plans while subscribed.
- To test: enter a personal anchor, choose or type a planning area, continue to preferences, accept the AI disclosure, create a preview, then tap Reveal Full Plan to view the paywall.
- The paywall includes subscription terms, Restore Purchases, and Manage Subscription when an active subscription is detected.
- Location access is used only to suggest a nearby planning area; users can type a planning area instead.
- The app should be reviewed with legal/support pages live at the URLs above.
