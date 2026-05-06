# Resident mobile — features overview

Flutter app in `divine_app/`. Confirm routes in `lib/core/routing/app_router.dart` before promising guard-only flows.

## Resident mobile (`divine_app/`)

Authentication; home dashboard & stats; notices/documents/polls/events; complaints; maintenance & payment history; amenity booking; parcels; visitor history & **pre-approve visitor** (multi-step flow); SOS; profile & settings; family members; vehicles; daily help; emergency contacts; notifications UI; dark mode / API URL settings.

Push notifications: optional — see [DEVELOPMENT.md](./DEVELOPMENT.md) and [FIREBASE_BUILD.md](./FIREBASE_BUILD.md).

## Guard (API + partial UI)

Backend supports guard flows. **Flutter** may include guard placeholders; confirm `divine_app` routes before promising guard-only features.

## Design / UX (Flutter)

Centralized tokens (colors, typography, spacing, radii) live under `divine_app/lib/core/theme/`. New screens should reuse these for consistency.

## Related docs

- **App structure:** [APP.md](./APP.md)  
- **Run & networking:** [DEVELOPMENT.md](./DEVELOPMENT.md)  
- **Backend features:** [../../backend/docs/FEATURES.md](../../backend/docs/FEATURES.md)  
- **Billing API contract:** [../../backend/docs/maintenance-billing-mobile-contract.md](../../backend/docs/maintenance-billing-mobile-contract.md)  
- **Monorepo README:** [../../README.md](../../README.md)
