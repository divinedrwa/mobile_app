# Divine App → Kotlin Multiplatform (KMP) Migration Spec

> **Status:** Planning + review complete. Target stack: **Kotlin Multiplatform + Compose Multiplatform (CMP)**.
> **Goal stated by owner:** native UI/performance with shared Compose UI.
> **Generated:** 2026-06-14. Source app: `divine_app/` (Flutter, ~103k LOC, 122 screens).

---

## 0. Read this first — what "migration" means here

There is **no Dart→Kotlin transpiler**. Every file is rewritten by hand. The data/repository
*structure* maps cleanly (Dio→Ktor, models→`@Serializable` data classes); the UI (Flutter
widgets + Riverpod) is a **full rewrite** in Compose + a chosen MVVM stack.

**Important honesty note on the goal:** Compose Multiplatform on **Android** is fully native
Jetpack Compose. On **iOS** CMP renders through Skia (Skiko), *not* UIKit/SwiftUI — i.e. the
same "drawn, not native-widget" model Flutter already uses. So CMP gives native Android + a
Flutter-equivalent iOS. A *truly* native iOS UI would require shared-logic-only + SwiftUI,
which is a different (larger) effort. This spec assumes the chosen **CMP** path.

---

## 1. Scope summary

| Module | Screens | Notes |
|--------|--------:|-------|
| Auth | 3 | splash, login, society selection |
| Resident | 67 | core, maintenance/payments, visitors/household, community/governance |
| Guard | 20 | gate ops, QR scan, patrols, incidents, shifts |
| Admin | 32 | management + analytics dashboards |
| **Total** | **122** | + core infra (routing, network, theme, session, storage) |

`divine_app` LOC: ~103k total; ~92k in features. UI-heavy (183 presentation files vs 124 data files, 0 domain files).

---

## 2. Target architecture (`divine_kmp/`)

Built in a **separate folder**, parallel to the Flutter app, which keeps shipping until cutover.

```
AdminDashBoard/
├── backend/          # unchanged — source of truth
├── frontend/
├── divine_app/       # current Flutter app (keeps shipping)
└── divine_kmp/       # NEW KMP project
    ├── composeApp/           # Compose Multiplatform UI (shared)
    │   └── src/
    │       ├── commonMain/   # all shared UI + viewmodels
    │       ├── androidMain/  # actual: camera, biometric, razorpay, etc.
    │       ├── iosMain/       # actual: camera, biometric, razorpay, etc.
    │       └── desktop/webMain (optional later)
    ├── shared/               # KMP module: data + domain + presentation logic
    │   └── src/commonMain/kotlin/
    │       ├── network/      # Ktor client + interceptor-equivalent plugins
    │       ├── data/         # repositories, datasources
    │       ├── domain/       # entities, use cases (the layer the Flutter app lacks)
    │       ├── model/        # @Serializable DTOs + enums
    │       └── di/           # Koin modules
    ├── iosApp/               # Xcode wrapper project
    └── androidApp/           # Android Application + MainActivity
```

### Library mapping (decisions)

| Concern | Flutter (today) | KMP target | Confidence |
|--------|-----------------|-----------|-----------|
| HTTP | Dio + interceptors | **Ktor client** + plugins | High — clean map |
| JSON | manual `fromJson` | **kotlinx.serialization** | High |
| State mgmt | Riverpod | **ViewModel + StateFlow** (`moko-mvvm` or Jetpack MP ViewModel) | High |
| DI | Riverpod providers | **Koin** | High |
| Navigation | GoRouter | **Voyager** or **Decompose** (deep links + nested tabs) | Medium — pick early |
| Routing model | go_router redirect guards | central role-guard in a root composable / Decompose component | Medium |
| Local prefs | SharedPreferences | **multiplatform-settings** | High |
| Secure storage | flutter_secure_storage | **expect/actual** (Keychain / Android Keystore) | Medium |
| Images | cached_network_image | **Coil 3** (multiplatform) | High |
| Charts | fl_chart | **Vico** (CMP) or custom Canvas | Medium |
| Date/format | intl | **kotlinx-datetime** + expect format | Medium |
| Markdown | flutter_markdown | `multiplatform-markdown-renderer` or HTML-in-WebView | Medium |
| WebView | webview_flutter | **expect/actual** (WKWebView / Android WebView) or CMP webview lib | Medium |
| QR generate | qr_flutter | `qrcode-kotlin` or Canvas | High |
| QR scan | mobile_scanner | **expect/actual** (CameraX / AVFoundation + Vision/MLKit) | **Low — high effort** |
| Image picker | image_picker | **expect/actual** or `peekaboo`/`moko-media` | Medium |
| Biometric | local_auth | **expect/actual** (BiometricPrompt / LocalAuthentication) | Medium |
| Push | firebase_messaging | GitLive Firebase KMP SDK or **expect/actual** | Medium |
| Razorpay | razorpay_flutter | **expect/actual → native Razorpay SDKs** (no KMP SDK) | **Low — high effort** |
| PhonePe | webview + polling | CMP/expect WebView + shared polling | Medium |
| UPI intent | url_launcher | **expect/actual** (Intent / URL scheme) | High |
| Share | share_plus | **expect/actual** (ACTION_SEND / UIActivityViewController) | High |
| URL launch / dial | url_launcher | **expect/actual** | High |
| Haptics | HapticFeedback | **expect/actual** (Vibrator / UIImpactFeedbackGenerator) | High |
| PDF | pdf + path_provider | **expect/actual** generate+save+share | Medium |
| In-app update | in_app_update | Android-only **actual** (Play Core); iOS no-op | Medium |
| Cert pinning | dio_cert_pinning | Ktor engine TLS config (expect) | Medium |

### `expect/actual` surface (the native bridges to build)

QR scanner (camera), image picker, biometric auth, secure storage, Razorpay SDK,
WebView, UPI intent launch, share sheet, phone dial / url launch, haptics, system sound,
PDF save/share, push notifications, device-info/integrity, display-zoom metrics,
in-app update. **These are the schedule risk** — front-load the spikes (Razorpay + camera).

---

## 3. API endpoint catalog (backend is unchanged)

The KMP client talks to the *same* `/api` backend. Endpoints in use, grouped:

### Auth / public
- `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `POST /auth/register-with-invitation`
- `GET /public/societies`, `GET /public/app-version`
- `POST /notifications/devices`, `POST /notifications/devices/remove`

> 401-refresh **exempt paths**: `/auth/login`, `/auth/register-with-invitation`, `/auth/logout`, `/auth/refresh`, `/notifications/devices`, `/notifications/devices/remove`.

### Resident — profile / dashboard
`GET|PATCH|DELETE /residents/me`, `PATCH /residents/change-password`, `GET /residents/dashboard`,
`GET /residents/community-directory`, `GET /banners/active/list`, `POST /banners/:id/register`,
`GET /water-supply/status`, `GET /vendors`, `GET /notifications` + mark-read/mark-all-read/delete.

### Resident — maintenance / payments
`GET /residents/my-maintenance`, `/residents/maintenance-pending`, `/residents/outstanding-dues`,
`GET /v1/cycles/current`, `/v1/billing-cycles`, `/v1/billing-cycles/context`, `/v1/financial-years`,
`GET /v1/maintenance/dashboard`, `GET /v1/maintenance` (history),
`POST /v1/payments/create-order` · `/v1/payments/razorpay/order`,
`GET /v1/payments/razorpay/status/:orderId`,
`POST /v1/payments/phonepe/initiate`, `GET /v1/payments/phonepe/status/:txnId`,
`GET /v1/payments/receipt.pdf?cycleId=`,
`GET /residents/upi-config`, `POST /residents/upi-payment-submit`, `GET /residents/my-upi-payments`.

### Resident — visitors / household
`GET /residents/my-visitors`, `/residents/visitor-approval-requests[/:id]` (+ approve/reject),
`GET /residents/my-pre-approved-visitors`, `POST /residents/pre-approve-visitor`, `DELETE /residents/pre-approved/:id`,
`GET /residents/my-parcels[/:id]` + `/collected`,
`GET /residents/my-vehicles` + register/patch/delete, `GET /residents/my-vehicle-log`,
`GET /residents/my-family` + add/patch/delete, `GET /residents/emergency-contacts` + add/patch/delete,
`GET /residents/my-staff` + add/delete.

### Resident — community / governance / amenities / SOS
`GET /residents/my-amenities`, `/residents/my-bookings`, `POST /residents/book-amenity`, `/bookings/:id/cancel`,
`GET /residents/my-notices`, `/residents/my-polls`, `POST /polls/:id/vote`,
`GET /residents/events[/:id]` + `/register`, `GET /residents/my-documents`,
`POST /residents/complaints`, `GET /residents/my-complaints`,
`POST /sos-alerts`, `GET /residents/sos/active`, `/residents/my-sos[/:id]`, `POST /sos-alerts/:id/{cancel,start}`,
`GET /residents/society-expenses[/:id]` + `/categories`,
`GET /residents/special-projects[/:id]` + `/expenses`.

### Guard
`GET /guards/my-dashboard`, `/my-gate`, `/my-shifts`, `/active-alerts`,
`POST /guards/visitor-checkin`, `/visitor-confirm-entry`, `/visitor-checkout`, `/visitor-otp-verify`,
`/visitor-approve-entry`, `/visitor-entry-notify`, `/pre-approved-admit`,
`GET /guards/pending-visitors`, `/my-visitors?from&to`, `/pre-approved-entries`,
`POST /guards/parcel-received`, `GET /guards/parcels-pending`, `POST /guards/parcels/:id/delivered`,
`POST /guards/gate-vehicle/entry`, `/gate-vehicle/:id/exit`, `GET /guards/gate-vehicle/today`,
`POST /guards/start-patrol`, `/patrol-checkpoint`, `GET /guards/my-patrols`, `/patrols-today`,
`POST /guards/incidents`, `/soc-broadcast`, `GET /guards/residents-directory?q=`.

### Admin
Dashboard/aggregate (`/visitors`, `/parcels`, `/complaints`, `/maintenance-management/financial-dashboard`),
residents (`/resident-management/*`), villas (`/villas*`, `/maintenance-management/villa-history/:id`),
expenses (`/expenses*`), notices (`/notices*`), polls (`/polls*`), parcels, parking (`/parking-management/*`),
patrols (`/guard-patrols*`), incidents, guard shifts (`/guard-shifts*`), staff (`/staff*`),
SOS (`/sos-alerts*`), society settings, role mgmt (`/users*`), invitations,
reconciliation (`/reconciliation/*`), complaint analytics (`/complaint-analytics/*`),
gate analytics (`/gate-analytics/*`), water analytics (`/water-supply-analytics/*`),
gate utilities (`/water-supply/*`, `/garbage-collection/*`, `/gates`),
UPI verification (`/upi-payments/*`), amenities (`/amenities*`), bank accounts (`/bank-accounts*`),
special projects (`/special-projects*`), data tools (`/import/*-csv`, `/export/*-csv`).

> **Note on response shapes:** list endpoints wrap in feature-specific keys (`{ items }`, `{ visitors }`, `{ preApproved }`, `{ summary }`, …). No universal envelope — confirm each key against the backend handler when writing the DTO.

---

## 4. Full screen inventory & per-screen notes

Legend — **Native?** = needs an `expect/actual` bridge beyond plain Ktor+Compose.

### 4.1 Auth (3)
| Screen | Route | Native? | Key notes |
|--------|-------|:------:|-----------|
| Branded splash | `/` | — | session check → route by role; staggered intro animation → Compose `AnimatedVisibility` |
| Login | `/login` | ✅ biometric, secure storage, haptics | society badge, remember-me, biometric unlock; `POST /auth/login` |
| Society selection | `/society-select` | — | `GET /public/societies`, filter ACTIVE, persist choice |

### 4.2 Resident — core (9)
shell (bottom nav / rail, badge), home (dashboard widgets, banners, quick actions, finances),
overview (metric tiles), profile (hero + sections), edit-profile (✅ image picker, multipart),
settings (✅ biometric/secure storage/url launch), notifications-center (✅ url launch; swipe actions),
community (tab host), community-directory (✅ dial; debounced paginated search).

### 4.3 Resident — maintenance & payments (15)
maintenance dashboard (5 tabs, admin-conditional), payment-history, maintenance hub (donut, streak),
my-dues, maintenance-history, cycle-detail (✅ PDF receipt), payment-method-selection,
**razorpay (io/stub)** (✅✅ Razorpay SDK + web Checkout.js + polling),
**phonepe (io/stub)** (✅ WebView + polling), upi-payment (✅ UPI intent, QR, clipboard, lifecycle),
payment-success (✅ haptics), payment-pending-verification (poll), gateway-poll-actions (pure util).

### 4.4 Resident — visitors / vehicles / household (19)
visitor-approval-requests / -detail (✅ cached image) / -history (paginated) / -success (✅ QR, share, dial),
pre-approve-visitor (4-step wizard, date/time pickers), my-pre-approved-visitors (✅ share/dial/clipboard, QR),
vehicles / add-vehicle / vehicle-log, daily-help / add-daily-help (✅ image picker, dial) / vendors-staff (✅ dial),
family-members / add-family-member (date picker), emergency-contacts / add-emergency-contact,
parcel-management, utilities (water/garbage tabs), incidents (✅ cached image).

### 4.5 Resident — community / governance (17 incl. special-projects)
events-list / event-detail (✅ share, register), polls-list / poll-detail (vote, animated bars),
notices-list / notice-detail (✅ share), complaint (✅ haptics, form) / my-complaints (paginated),
sos (✅ press-and-hold, haptics, dial; `POST /sos-alerts` → 409 if active) / active-sos (✅ dial; 5s poll),
society-expenses (search) / expense-detail (✅ url launch attachments),
documents-list (✅ url launch), **legal-markdown** (✅ markdown render) / **legal-webview** (✅ WebView),
special-projects / -detail; admin-special-projects / -create / -detail (nested CRUD, segmented villa picker).

### 4.6 Guard (20)
dashboard (metrics, quick actions, SOS strip), check-in (✅ image picker, multi-resident),
**qr-scan (io/stub)** (✅✅ camera scanner — highest-risk), active-entries (4 tabs + mutations),
visitor-approval (OTP verify, notify, ✅ dial), visitor-detail (✅ dial), pre-approved-arrival,
pre-approved-list, vehicle-entry, delivery-quick (brand grid), patrol (start + checkpoint dialogs),
incident-report (type/severity), shift-details, today-summary (combined providers),
logs (date range, tabbed, debounced search), residents-directory (✅ dial, debounced),
emergency (✅ long-press, haptics, system sound), profile (theme toggle, logout).

### 4.7 Admin (32)
dashboard; residents; villas; villa-history; complaints; complaint-analytics (✅ charts);
amenities; expenses; bank-accounts; outstanding-dues; reconciliation; upi-verifications;
notices; polls; parcels; parking; patrols; incidents; guard-shifts; staff; sos;
society-settings; role-management; invitations; reminders; maintenance-hub; maintenance-actions (✅ haptics);
gate-analytics (✅ charts); gate-utilities; water-analytics (✅ charts); **data-tools** (✅ file picker, CSV import/export); placeholder.

---

## 5. Phased implementation plan

Each phase is shippable/testable on its own. Phases 0–2 de-risk; 3+ deliver features.

- **Phase 0 — Scaffold & spike (de-risk).** Create `divine_kmp/` Gradle+CMP project; Android + iOS run a "hello". Stand up Ktor against the live backend. Prove the two highest-risk natives early: **Razorpay checkout** and **camera QR scan**, plus one end-to-end **auth → one resident screen** flow. *Gate: if Razorpay/camera interop is acceptable, continue.*
- **Phase 1 — Foundation.** Ktor client + interceptor-equivalent plugins (society header, auth bearer, 401-refresh single-fire, retry, error mapping, cert pinning). kotlinx.serialization DTOs + enums. multiplatform-settings + secure-storage expect/actual. Koin DI. Theme (Material 3 tokens, typography, spacing). Navigation shell (Voyager/Decompose) + role-guard. Session/account-deactivated handlers.
- **Phase 2 — Auth.** splash, society-selection, login (+ biometric expect/actual). Full login→role-routing working on both platforms.
- **Phase 3 — Resident core.** shell, home, overview, profile, edit-profile (image picker), settings, notifications-center, community host, directory.
- **Phase 4 — Resident maintenance & payments.** dashboard/hub/dues/history/cycle-detail, payment-method-selection, **Razorpay**, **PhonePe**, UPI, success/pending. (Razorpay/PhonePe natives delivered here, spiked in P0.)
- **Phase 5 — Resident visitors/household.** approvals, pre-approve wizard, vehicles, daily-help, family, emergency, parcels, utilities, incidents. (QR generate, share, dial.)
- **Phase 6 — Resident community/governance.** events, polls, notices, complaints, SOS (press-hold + poll), expenses, documents, markdown/webview, special-projects.
- **Phase 7 — Guard.** dashboard, check-in, **QR scan** (camera native delivered here), active-entries, approvals, vehicle/delivery, patrol, incidents, shifts, logs, directory, emergency, profile.
- **Phase 8 — Admin.** management CRUD screens first, analytics (charts) second, data-tools (file picker) last.
- **Phase 9 — Cutover.** Push notifications, in-app update, parallel beta, parity QA per screen, retire Flutter app.

### Effort reality
~122 screens, ~103k LOC, ~18 native bridges. This is a **multi-month, multi-engineer** rewrite, not a port. Per-phase parity QA against the live Flutter app is the acceptance gate.

---

## 6. Cross-cutting conventions for the rewrite

- **State:** one `ViewModel` per screen exposing `StateFlow<UiState>`; `UiState` is a data class or `sealed`(`Loading/Data/Error`) mirroring Riverpod `AsyncValue`.
- **Errors:** Ktor plugin maps HTTP → a `sealed AppException` (`Network/Validation/Unauthorized/Forbidden/NotFound/Server`). 401 (non-exempt) → single-fire session-expired callback → logout+route to login. "deactivated"/"inactive" message → account-deactivated callback.
- **Multi-tenant:** send `X-Society-Id` from the JWT-derived societyId on every request (defensive cross-check; JWT is source of truth). Never let a SUPER_ADMIN token hit tenant routes.
- **Pagination:** shared `PaginationState<T>` + `loadMore()/refresh()`; debounced search via `Flow.debounce`.
- **Conditional `_io/_stub`** Dart files → single `expect` declaration with per-target `actual`s (no multi-file conditional imports).
- **Models:** `@Serializable` data classes; tolerate unknown JSON keys (`ignoreUnknownKeys = true`); confirm wrapper key per endpoint.

---

## 7. Open decisions to lock before Phase 1

1. **Navigation lib:** Voyager (simpler, screen-based) vs Decompose (component-based, better deep-link/state-restoration). *Recommendation: Decompose for the role-guarded nested-tab shells.*
2. **ViewModel lib:** Jetpack MP ViewModel vs moko-mvvm. *Recommendation: Jetpack ViewModel (now multiplatform).*
3. **iOS UI reality:** accept CMP/Skia on iOS (this spec) or split to SwiftUI for native iOS (re-scope).
4. **Push:** GitLive Firebase KMP SDK vs hand-rolled expect/actual FCM.
5. **Min versions / package id:** reuse `com.app.gatepass` or new id for parallel install during beta.

---

## 8. Appendix — high-risk items (front-load)

1. **Razorpay** — no KMP SDK. Android: `com.razorpay:checkout`; iOS: Razorpay iOS pod via cinterop/Swift; web: Checkout.js. Shared: order create + status polling (pure Ktor).
2. **QR camera scan** — CameraX (Android) + AVFoundation/Vision (iOS); animated overlay via Compose Canvas.
3. **WebView (PhonePe + legal)** — expect/actual WKWebView/Android WebView with navigation-delegate interception.
4. **Markdown** — `multiplatform-markdown-renderer`, else precompile to HTML and use WebView.
5. **Charts** — Vico (CMP) for analytics screens, else custom Canvas.
6. **Secure storage / biometric** — Keychain + LocalAuthentication (iOS); Keystore + BiometricPrompt (Android).
