# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter mobile app for society/community management ("Divine Society Management App"). Supports three user roles: Resident, Guard, and Admin. Backend API runs separately on port 4000.

- **Package ID**: `com.app.gatepass`
- **Dart SDK**: ^3.11.5
- **Platforms**: iOS, Android

**Human-readable docs:** `docs/` — [DEVELOPMENT.md](./docs/DEVELOPMENT.md), [APP.md](./docs/APP.md), [FEATURES.md](./docs/FEATURES.md), [FIREBASE_BUILD.md](./docs/FIREBASE_BUILD.md); app entry [README.md](./README.md).

## Common Commands

```bash
flutter pub get              # Install dependencies
flutter run                  # Debug build (auto-detects connected device)
flutter analyze              # Static analysis (uses flutter_lints)
flutter test                 # Run all tests
flutter test test/features/  # Run feature tests only
flutter build apk            # Android release build
flutter build ipa            # iOS release build
dart run build_runner build  # Run code generation (build_runner)
```

### Environment overrides via dart-define

```bash
# Full base URL (production):
flutter run --dart-define=API_BASE_URL=https://api.example.com/api

# LAN host only (physical device on local network):
flutter run --dart-define=API_HOST=192.168.1.42
```

API base URL resolution order: `API_BASE_URL` dart-define → saved URL from device settings → `API_HOST` dart-define + port 4000 → simulator defaults (10.0.2.2 Android / 127.0.0.1 iOS).

## Architecture

### Clean Architecture with Riverpod

Each feature module in `lib/features/` follows this structure:

```
features/<name>/
├── data/
│   ├── datasources/    # Remote/local data sources (Dio calls)
│   └── repositories/   # Concrete repository implementations
├── domain/
│   ├── entities/       # Business objects
│   └── repositories/   # Abstract repository contracts
└── presentation/
    ├── pages/          # Screen widgets
    ├── providers/      # Riverpod providers (StateNotifier pattern)
    └── widgets/        # Feature-specific UI components
```

### Key Patterns

- **State management**: Riverpod (`flutter_riverpod`). Providers live in each feature's `presentation/providers/`. Shared providers in `lib/shared/providers/`.
- **Error handling**: repositories throw typed `AppException` subclasses defined in `lib/core/errors/exceptions.dart`. [ErrorInterceptor](lib/core/network/interceptors/error_interceptor.dart) maps Dio errors to those exceptions; presenter providers (Riverpod) catch them and surface user-friendly messages. There is no `Either<Failure, T>` / `dartz` layer despite older docs that claimed otherwise.
- **HTTP client**: Singleton `DioClient` (`lib/core/network/dio_client.dart`) with AuthInterceptor (JWT from StorageService) and ErrorInterceptor. Always access via `DioClient.dio` — never cache the instance. Call `DioClient.reset()` after logout or base URL change.
- **Routing**: GoRouter (`lib/core/routing/app_router.dart`) with role-based redirect. Three top-level route trees: `/resident/*`, `/guard/*`, `/admin/*`. Shell navigators provide bottom navigation.
- **Local storage**: Hive for cached data, SharedPreferences via `StorageService` for auth tokens and settings.

### Core Directories

- `lib/core/constants/app_constants.dart` — Enums (UserRole, VisitorType, BookingStatus, etc.), storage keys, API URL resolution logic
- `lib/core/network/` — DioClient, auth/error interceptors
- `lib/core/routing/` — GoRouter config with role-based guards
- `lib/core/theme/` — Material 3 light/dark themes, design tokens
- `lib/core/widgets/` — Reusable UI components
- `lib/shared/` — Cross-feature models (UserModel), providers, services, widgets

### Feature Modules

`auth`, `resident`, `guard`, `home`, `profile`, `visitors`, `amenities`, `complaints`, `maintenance`, `sos`

### Firebase

Optional — the app gracefully degrades without Firebase config files. Used for push notifications (FCM) and analytics. Config files: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`. See `docs/FIREBASE_BUILD.md`.

## API Endpoints

Centralized in `lib/core/constants/api_endpoints.dart`. Dio paths are absolute (e.g., `/auth/login`, `/residents/me`). The backend prefixes everything under `/api`.

## Testing

Uses `flutter_test`, `mockito`, and `mocktail`. Tests mirror the feature structure under `test/features/`.
