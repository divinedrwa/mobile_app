# Flutter app — structure & API usage

## Purpose

Resident-facing **Flutter** application in `divine_app/`. It consumes the same **`/api`** backend as the admin site, primarily under **`/residents/*`** routes.

## Tech stack

| Layer | Choice |
|-------|--------|
| UI | Material, custom design tokens (`lib/core/theme/design_tokens.dart`, spacing, typography) |
| State | Riverpod |
| HTTP | Dio + auth & error interceptors (`lib/core/network/`) |
| Routing | GoRouter (`lib/core/routing/app_router.dart`) |
| Storage | Hive, SharedPreferences (tokens, user, optional API base URL override) |
| Push (optional) | Firebase Messaging / Core |

## Routing (high level)

- `/` — splash  
- `/login` — authentication  
- `/resident` — **ResidentShell** (tabs: home, community, profile)  
- Nested examples: `pre-approve-visitor`, `sos`, `maintenance-payment`, `amenities`, `complaint`

Guard/admin destinations may exist as placeholders — most implementation effort is **resident**.

## API base URL

Implemented in `AppConstants.baseUrl` (`lib/core/constants/app_constants.dart`):

1. `API_BASE_URL` dart-define (production)  
2. User-saved URL from settings  
3. `API_HOST` dart-define  
4. Emulator / simulator defaults (`10.0.2.2` vs `127.0.0.1`)  
5. Physical device: configurable LAN IP  

Paths in code are usually absolute (`/auth/login`, `/residents/...`) appended to this base.

## Resident features (typical)

Authentication; dashboard & banners; profile; community content (notices, documents, polls, events); complaints; maintenance & payments; amenities & bookings; parcels; visitors & **pre-approve flow**; SOS; family, vehicles, daily help, emergency contacts; notifications UI; settings (theme, API override, etc.).

Optional: **push notifications** after Firebase setup ([DEVELOPMENT.md](./DEVELOPMENT.md), [FIREBASE_BUILD.md](./FIREBASE_BUILD.md)).

## Project layout (Flutter)

```text
divine_app/lib/
├── core/           # theme, constants, routing, network, errors, services
├── features/       # auth, resident (pages, providers, repositories, models)
├── shared/         # shared models/widgets
└── main.dart
```

## Related

- **Run & device networking:** [DEVELOPMENT.md](./DEVELOPMENT.md)
- **Maintenance billing API contract (mobile):** [../../backend/docs/maintenance-billing-mobile-contract.md](../../backend/docs/maintenance-billing-mobile-contract.md)
