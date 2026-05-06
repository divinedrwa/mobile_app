# My Society (Flutter)

Resident-facing mobile app in this folder. It uses the same **`/api`** backend as the admin site (`backend/`), mainly **`/residents/*`**.

## Documentation

| Doc | Contents |
|-----|----------|
| [docs/APP.md](./docs/APP.md) | Tech stack, routing, API base URL, project layout |
| [docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md) | Run, device networking, iOS signing, troubleshooting |
| [docs/FEATURES.md](./docs/FEATURES.md) | Mobile capability checklist |
| [docs/FIREBASE_BUILD.md](./docs/FIREBASE_BUILD.md) | Firebase / FCM on release builds |

**Maintenance billing (API contract for this app):** [../backend/docs/maintenance-billing-mobile-contract.md](../backend/docs/maintenance-billing-mobile-contract.md)

## Quick start

```bash
cd divine_app
flutter pub get
flutter run
```

Production / custom API host:

```bash
flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api
```

See [docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md) for LAN IP, emulators, and saved URL overrides.

## Monorepo

- Root: [../README.md](../README.md)  
- Backend setup: [../backend/docs/DEVELOPMENT.md](../backend/docs/DEVELOPMENT.md)
# mobile_app
