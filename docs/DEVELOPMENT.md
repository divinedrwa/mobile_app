# Flutter app — development

## Prerequisites

- **Flutter** 3.11+ (see `pubspec.yaml` SDK constraint)

## Run

```bash
cd divine_app
flutter pub get
flutter devices
flutter run -d <device-id>
```

## API base URL

Resolution order is implemented in `lib/core/constants/app_constants.dart`:

1. `--dart-define=API_BASE_URL=...` (full URL including `/api`)
2. Saved override from in-app settings (Hive / storage)
3. `--dart-define=API_HOST=...` (host only, port 4000)
4. Simulators: Android emulator → `10.0.2.2`, iOS Simulator → `127.0.0.1`
5. Physical device: `defaultPhysicalLanHost` in `app_constants.dart` (update when your dev machine’s LAN IP changes) or use `API_HOST`

The backend must listen on **`0.0.0.0`** (default in `backend/src/server.ts`) and the firewall must allow port **4000** for LAN testing.

## iOS code signing (physical device)

If Xcode shows “No Accounts” / signing errors:

1. Xcode → Settings → Accounts → add Apple ID  
2. Open `divine_app/ios/Runner.xcworkspace` → Runner target → Signing & Capabilities  
3. Enable **Automatically manage signing**, select your Team  

## Login & seed data

Default society admin and optional super admin are created from the backend. See [../../backend/docs/DEVELOPMENT.md](../../backend/docs/DEVELOPMENT.md) (seed section).

## Optional: Firebase (Analytics + FCM)

See [FIREBASE_BUILD.md](./FIREBASE_BUILD.md). Backend Firebase Admin env vars are documented in `backend/.env.example`.

## Building for production

```bash
flutter build apk    # or ios / appbundle
```

Use **`--dart-define=API_BASE_URL=...`** so release builds point at your production API.

## Troubleshooting

| Issue | Hint |
|-------|------|
| Mobile cannot reach API | Same Wi‑Fi as dev machine; correct IP / saved API URL; backend on `0.0.0.0:4000` |
| Zod validation errors | Prefer showing backend `issues[]` to the user |

## App structure & features (overview)

See [APP.md](./APP.md) and [FEATURES.md](./FEATURES.md).

## Related

- **Monorepo index:** [../../DEVELOPMENT.md](../../DEVELOPMENT.md)
