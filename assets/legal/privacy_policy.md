# Privacy Policy

**Service:** GatePass+ (the "Service", "Platform", "we", "us", "our")
**Effective date:** 12 May 2026
**Last updated:** 18 July 2026
**Governing law:** Republic of India — Digital Personal Data Protection Act, 2023 ("DPDP Act") and the Information Technology Act, 2000 with rules made thereunder (including the IT (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011 and the IT (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021).
**Contact for privacy matters / Grievance Officer:** divine.drwa@gmail.com

GatePass+ is a multi-tenant housing-society operations platform delivered as a mobile application for Residents and Guards (Android and iOS, package id `com.app.gatepass`) and a web administration dashboard for society administrators. This Privacy Policy explains what personal data we collect about you, why we collect it, how we use and protect it, who we share it with, and the rights you have over your data.

This Privacy Policy applies to every person who uses the Service — Residents, members of their household, Guards, Society Administrators ("Admins"), Vendors invited to interact with a Society, and visitors whose details are recorded at the gate. By installing, signing into, or otherwise using the Service, you acknowledge that you have read and understood this Privacy Policy.

---

## 1. Quick summary (non-binding)

* GatePass+ is operated as a **Data Fiduciary** under the DPDP Act for the personal data we determine the purpose and means of processing for.
* Each Society (Resident Welfare Association or similar community) using GatePass+ is a **joint Data Fiduciary** with us for data of its members and its visitors. Your Society may set additional rules; ask your Society for its own privacy notice if it has one.
* We collect only the data needed to run housing-society workflows: identity & contact details, household composition, visitor logs, maintenance billing, **online payment transaction metadata** (via Razorpay, PhonePe, or UPI reference submissions — never card numbers or UPI PINs), complaints, gate activity, push-notification tokens, and basic device information.
* We **do not** sell personal data. We **do not** use your data to train any AI/ML system.
* You can request access, correction, erasure, grievance redress and account deletion at **divine.drwa@gmail.com**, or in-app via **Settings → Account → Delete account**.

The detailed terms below override this summary in case of any conflict.

---

## 2. Who we are and how to reach us

| | |
|---|---|
| Service name | GatePass+ |
| Application packages | Android: `com.app.gatepass` · iOS: `com.app.gatepass` |
| Operating context | Operated for and on behalf of the **Divine Residency Welfare Association ("DRWA")** and other subscribing Resident Welfare Associations / housing societies |
| Privacy & grievance contact | divine.drwa@gmail.com |
| Grievance Officer | The officer designated at the email above acts as both the **Grievance Officer under Rule 5(9) of the IT (Reasonable Security Practices) Rules, 2011 / Rule 3(2) of the IT (Intermediary Guidelines) Rules, 2021** and the **point of contact for grievance redressal under Section 8(10) of the DPDP Act, 2023**. We will acknowledge your communication within 24 hours and respond within 15 (fifteen) days of receipt. |

If you cannot reach us, you may also write to the **Data Protection Board of India** once it is operational, in accordance with the DPDP Act.

**Language of this notice (DPDP Act §5(3)):** You may access this Privacy Policy and any consent notice we present in **English or in any language listed in the Eighth Schedule to the Constitution of India**. To request a copy in another such language, write to **divine.drwa@gmail.com** and we will provide one.

---

## 3. Definitions

For this Policy:

* **"Personal Data"** means any data about an individual who is identifiable by or in relation to such data, as defined under Section 2(t) of the DPDP Act.
* **"Sensitive Personal Data or Information" ("SPDI")** has the meaning given in Rule 3 of the IT (RSP) Rules, 2011 — including passwords, financial information such as bank account or payment instrument details, biometric information, etc.
* **"Data Principal"** means the natural person to whom Personal Data relates.
* **"Data Fiduciary"** means the entity that determines the purpose and means of processing of Personal Data.
* **"Data Processor"** means an entity that processes Personal Data on behalf of a Data Fiduciary.
* **"Society"** means a Resident Welfare Association, Apartment Owners' Association, housing co-operative or similar community that has on-boarded onto the Service.
* **"Resident"**, **"Guard"**, **"Admin"**, **"Super-Admin"** refer to the roles defined in the Service.

---

## 4. The personal data we process

We process **only** the categories listed below. We do not collect contacts, call logs, SMS messages, calendar, health data, precise device location in the background, or advertising identifiers.

### 4.1 Account & identity (all roles)

| Field | Source | Purpose |
|---|---|---|
| Full name | You / your Admin during onboarding | Identifying you in the Society |
| Username | You / your Admin | Login credential |
| Email address | You / your Admin | Login, security alerts, password recovery |
| Phone number | You / your Admin | Gate verification, OTP for pre-approved visitors, contactability |
| Hashed password | Generated when you set a password | Authentication. We store only a **bcrypt** hash (cost factor 10); your plaintext password is never stored or logged. |
| Role (`ADMIN` / `RESIDENT` / `GUARD` / `SUPER_ADMIN`) | Assigned by your Society or, for `SUPER_ADMIN`, by us | Authorising access |
| Society id, Villa/Unit id | Your Admin or invite token | Tenancy isolation |
| Move-in / move-out date | Your Admin | Maintenance billing periods |
| Profile photo | You (optional) | Display in your profile, complaint cards, visitor approvals |
| Account status (active / inactive) | System | Login control |

### 4.2 Household & relationship data (Residents)

| Field | Where it lives | Notes |
|---|---|---|
| Family members — name, relationship, age, phone, ID-proof reference | `FamilyMember` records | Optional. Editable from Profile → Family. |
| Emergency contacts — name, relationship, phone, address | `EmergencyContact` records | Optional. Used by the Society in case of incidents. |
| Vehicles — registration number, make, model, colour, parking slot, RC-copy reference | `Vehicle` records | Used at the gate to identify resident vehicles. |
| Domestic-staff details — name, type (maid, driver, etc.), phone, address, ID-proof reference, photo | `Staff` records (managed by Admin) | Society maintains these records; Residents see assignments to their unit. |

### 4.3 Visitor & gate-activity data

| Field | Notes |
|---|---|
| Visitor name, phone number, purpose of visit, visitor type (`GUEST` / `DELIVERY` / `SERVICE_PROVIDER` / `VENDOR` / `CONTRACTOR` / `OTHER`) | Captured by the Guard or the Resident during a pre-approval. |
| Visitor vehicle number | Optional. |
| Visitor photo | Optional; captured by the Guard. Stored on our infrastructure with restricted access (see §6). |
| Check-in / check-out timestamps and gate id | System-generated. |
| Pre-approval OTP and validity window | Generated by the Service for residents' invited guests. |
| Multi-villa approval response (approve / reject) by Residents | Audit trail for gate decisions. |

### 4.4 Parcel, complaint, poll, notice and document data

| Field | Notes |
|---|---|
| Parcel — sender name, tracking number, delivery service, description, status, timestamps | Logged by the Guard or Admin. |
| Complaint — title, description, category, status, admin notes, resolution timestamp, resident id | Filed by Residents; visible to the Society Admin. |
| Notice — title, content, category, priority, recipient list | Published by Admin to one or more Residents. |
| Poll vote — option id, villa id, timestamp | Votes are recorded per **villa**, not per individual resident. |
| Document — title, category, file reference, uploader | Uploaded by Admin (society bye-laws, agreements, etc.). |

### 4.5 Incident, SOS and patrol data

| Field | Notes |
|---|---|
| Incident — title, description, severity, optional location text, optional photo, reporting Guard id | Logged by Guards for the Society Admin. |
| SOS alert — emergency type (`MEDICAL` / `FIRE` / `SECURITY` / `ACCIDENT` / `OTHER`), free-text message, response timeline, assigned Guard id | Triggered by the Resident in-app. **The current mobile build does not request device-location permission**, so latitude / longitude on SOS records remain null unless your Society configures an alternate source. |
| Guard shift, patrol, gate-vehicle ledger, water-supply and garbage-collection events | Operational logs maintained by Guards. |
| SOC broadcast — kind (`FIRE` / `MEDICAL` / `SECURITY`), note, timestamp, Guard id | Audit trail of emergency broadcasts to Admins. |

### 4.6 Financial data (maintenance billing)

GatePass+ is a **technology facilitator** for Society maintenance payments. **We are not** a bank, payment aggregator, or payment-system operator. Online payments are processed by licensed third-party gateways; funds settle to your **Society's own** gateway or bank account.

| Field | Notes |
|---|---|
| Per-villa monthly maintenance amount and due date | Set by the Society Admin. |
| Payment record — amount, date, mode, transaction id, receipt number, optional remarks, optional bank-account reference | Created when a payment is recorded (online or manual). |
| Gateway payment metadata — payment id, order id, signature, gateway status, amount, timestamp, method type | Received from **Razorpay** or **PhonePe** via webhook/callback, or from UPI flow status recorded by the Society. We store **non-sensitive transaction metadata only** — not card numbers, CVV, or UPI PIN. |
| UPI payment submission — amount, billing month/year, optional UPI transaction reference (UTR), optional remark, verification status | Submitted by you in **Maintenance** when you pay the Society's VPA directly; reviewed by your Society Admin before a payment record is created. |
| RWA bank-account details — bank name, account number, IFSC, holder name, account type | Set by the Admin so that residents can see where to remit dues. **This is the Society's own bank information, not the user's.** |
| Society UPI VPA / QR payee details | Configured by Admin; shown so you can pay the Society directly via your UPI app. |

We **never store** your debit-card, credit-card, UPI PIN, internet-banking password or any other payment-instrument credential. Such data is collected and handled **only by the payment gateway** (Razorpay, PhonePe, or your bank/UPI app) on their PCI-DSS-compliant interfaces.

### 4.7 Device & technical data

| Field | Notes |
|---|---|
| Push-notification token (FCM for Android, APNs token resolved via FCM for iOS) | Stored in `PushDevice` and tied to your account. Used to deliver visitor alerts, approvals, billing reminders, SOS notifications, etc. |
| Device id (a stable identifier supplied by `device_info_plus`) and device-model name | Used to differentiate multiple devices on the same account so a logout / token rotation only invalidates one device. |
| IP address, user-agent, HTTP request metadata | Logged transiently in server-access logs for security and abuse prevention. |
| App version, OS version | Captured for diagnostics. |

We **do not** use Android Advertising ID (AAID), iOS IDFA, or any other cross-app advertising identifier. The Service does not display advertisements.

### 4.8 Authentication artefacts on your device

| Item | Where it lives on your device | Why |
|---|---|---|
| JWT session token | App memory + `SharedPreferences` | Authenticates your API calls; cleared on logout. |
| Encrypted login credentials (only if you opt in to "Remember me" or "Sign in with biometrics") | iOS Keychain / Android Keystore via `flutter_secure_storage` | Lets the app re-authenticate after biometric prompts. Stays on the device; never transmitted to us. |
| Cached UI data (Hive boxes / `cached_network_image`) | App sandbox | Performance only. |
| Settings (theme, notification toggles) | `SharedPreferences` | App-local preferences. |

You can wipe all of the above at any time by uninstalling the app or using **Settings → Sign out**.

### 4.9 Admin audit log

For accountability, we record administrative actions in `AdminAuditLog` — the acting administrator's user id, action, entity type and id, optional metadata, and timestamp. These records are used only to investigate misuse, satisfy legal obligations, and prove compliance to your Society.

### 4.10 Categories of SPDI

The following items qualify as **Sensitive Personal Data or Information** under the IT (RSP) Rules, 2011:

* Your password (stored only as a one-way bcrypt hash; never in plaintext);
* Financial information (gateway transaction metadata — order id, payment id, status, amount; we do **not** hold raw card / UPI PIN / CVV credentials);
* Biometric matching on your device (Face ID / fingerprint) is performed entirely **on-device** by `local_auth`. **We do not collect, transmit, or store any biometric template, image, or signature.**

---

## 5. How and why we use your personal data

We process Personal Data for the following purposes. Where the DPDP Act requires a lawful basis we indicate it; where SPDI is involved we rely on your explicit consent obtained at the point of collection.

| # | Purpose | Categories | Lawful basis (DPDP Act) |
|---|---|---|---|
| 1 | Creating and operating your account in your Society | §4.1 | Performance of an obligation / Consent under §6(1) |
| 2 | Authenticating you (password, biometric prompt) | §4.1, §4.8 | Performance of contract; security |
| 3 | Recording and verifying visitors, deliveries, and vehicles at the gate | §4.3 | Legitimate use under §7(a) (where the data principal voluntarily provides data) and consent of visitors via gate-side signage / verbal notice given by the Guard |
| 4 | Pre-approval and OTP verification of guests invited by Residents | §4.3 | Consent of the Resident; the visitor is informed at the gate before the OTP is consumed |
| 5 | Issuing maintenance bills, recording payments, reconciling with payment gateways (Razorpay, PhonePe), and verifying direct UPI submissions | §4.6 | Performance of contract between Resident and Society; compliance with applicable financial-record laws |
| 6 | Sending operational notifications (visitor at the gate, new notice, payment receipt, SOS, complaint update, billing reminder) | §4.7 | Consent (push permission obtained at first launch on Android 13+ and on iOS) |
| 7 | Investigating incidents, complaints and security events | §4.4, §4.5, §4.9 | Legitimate use under §7(d) — interest of public order / safety where applicable, otherwise consent |
| 8 | Maintaining audit and security logs | §4.7, §4.9 | Legitimate use under §7(g) — compliance with law; security of processing |
| 9 | Improving the Service (crash diagnostics, aggregated event counts via Firebase Analytics) | §4.7 | Consent (you can disable in Settings → Notifications, and uninstall the app removes the SDK) |
| 10 | Responding to your rights requests, grievances and legal process | All categories as needed | Compliance with law |

We **do not** carry out automated decision-making with legal or similarly significant effect against you, and we do not use your data to train any AI or machine-learning model.

---

## 6. Who we share data with

We share Personal Data only with the parties listed below and only to the extent needed.

### 6.1 Within your Society

* Your Society's **Admin users** can view and manage data scoped to your Society (residents, villas, billing, visitors, complaints, etc.). Each Society is responsible for limiting which of its staff have Admin access.
* **Guards** of your Society can view visitor / vehicle / parcel records, your name and unit number when you're called at the gate, and SOS alerts in your Society.
* **Other Residents** can view the limited information you choose to share (e.g., your unit number, your name on a notice acknowledgement, or visitor approval responses on multi-villa visits).

Different Societies on the Platform are kept **logically isolated** — every database query is scoped by `societyId` and a Super-Admin role cannot access tenant routes without first creating a delegated session for a specific Society.

### 6.2 Sub-processors (Data Processors acting for us)

| Sub-processor | Role | Data shared | Where data is processed |
|---|---|---|---|
| **Neon (Neon Inc.)** — managed PostgreSQL | Primary database | All Service data described above | The database region selected at provisioning time |
| **Render (Render Services, Inc.)** | Application hosting for the Express API | All request data in flight | The Render region selected at provisioning time |
| **Cloudinary (Cloudinary Ltd.)** | Media storage for profile photos | Profile-photo bytes, public id, secure URL | Cloudinary's global CDN with the regions enabled on the account |
| **Google — Firebase Cloud Messaging (Google LLC / Google India Pvt. Ltd.)** | Push-notification delivery on Android and iOS | FCM token, notification payload (title, body, structured data) | Google's global infrastructure |
| **Google — Firebase Analytics** | Aggregated event analytics (when enabled) | Pseudonymous app-installation id, in-app event names, OS / device-class info | Google's global infrastructure |
| **Razorpay (Razorpay Software Pvt. Ltd.)** | Online payment processing for maintenance dues (cards, UPI, net-banking via Razorpay checkout) | Payment-instrument data (collected directly by Razorpay), payment id, order id, signature, amount, currency, Society / Villa reference | India |
| **PhonePe (PhonePe Pvt. Ltd.)** | Online payment processing for maintenance dues (UPI, cards via PhonePe checkout) | Payment-instrument data (collected directly by PhonePe), transaction id, status, amount, Society / Villa reference | India |
| **Apple Inc.** | Distribution of the iOS app and APNs delivery for push | Information you share with iOS as part of the app lifecycle | Apple infrastructure |
| **Google LLC** | Distribution of the Android app via Google Play and FCM delivery for push | Information you share with Google as part of the app lifecycle | Google infrastructure |

We bind every sub-processor by contract to confidentiality, security, and use of the data only as instructed by us, in line with §10 of the DPDP Act.

### 6.3 Disclosures required by law

We may disclose Personal Data when we believe in good faith that disclosure is required to:

* comply with an enforceable order of a court, tribunal or competent authority in India;
* respond to a request from a law-enforcement agency made under a written authorisation citing the specific law and offence under investigation;
* enforce our Terms and Conditions, or to investigate suspected fraud, abuse or violation of law;
* protect the rights, property or safety of the Service, our users, our Society customers, or the public.

We log every such disclosure in `AdminAuditLog`.

### 6.4 Disclosures we do **not** make

* We do **not** sell or rent Personal Data.
* We do **not** share data with advertisers or data brokers.
* We do **not** use your data for advertising or for tracking you across third-party apps and websites.

---

## 7. Push notifications

Push notifications power most of the time-critical workflows in the app (visitor at the gate, approval requests, SOS, payment receipt, billing reminder). When you install the app:

* **Android 13 and above:** the app requests the `POST_NOTIFICATIONS` runtime permission on first launch. If you decline, you can later enable it from Android Settings → Apps → GatePass+ → Notifications.
* **iOS:** the app requests notification permission on first launch via `flutter_local_notifications` / Firebase Messaging. If you decline, you can later enable it from iOS Settings → Notifications → GatePass+.

You may turn notifications off completely from the device settings above, and you can separately disable in-app push from **Settings → Notifications** inside the app. Disabling will not stop the **in-app inbox** entries (`UserNotification`) from being created — only the device-side push will be suppressed.

We use the channel id `default` for all notifications (created natively in `MainActivity.kt` so they appear even on cold start).

---

## 8. Permissions used by the mobile app, and why

We follow the principle of least privilege: every permission below is requested only when needed and used only for the purpose stated.

### 8.1 Android (declared in `AndroidManifest.xml`)

| Permission | Why we use it |
|---|---|
| `android.permission.INTERNET` | Talking to the GatePass+ API and Firebase. |
| `android.permission.CAMERA` | Taking visitor / incident / profile photos and scanning QR codes for pre-approved visits. Used only when you tap "take photo" or "scan QR". |
| `android.permission.USE_BIOMETRIC` | Optional biometric unlock on the login screen. Matching happens entirely on the device. |
| `android.permission.POST_NOTIFICATIONS` | Showing operational notifications (see §7). |

The app does **not** declare any location, contacts, SMS, call-log, microphone, Bluetooth, Health Connect, foreground-service, background-location, advertising-id, or media-store permissions beyond the ones above.

### 8.2 iOS (declared in `Info.plist`)

| Key | Why we use it |
|---|---|
| `NSCameraUsageDescription` | Photos for profile, complaints, daily-help registration and QR scanning. |
| `NSPhotoLibraryUsageDescription` | Choosing existing images from your library to attach to your profile, complaints or daily-help registration. |
| `NSMicrophoneUsageDescription` | Declared because `image_picker` can capture video clips with audio. The current app flows do not record video. |
| `NSFaceIDUsageDescription` | Face ID prompt for optional biometric login. Matching is performed on-device by iOS; no biometric data leaves your device. |
| `NSLocalNetworkUsageDescription` | Allows physical devices on the same LAN to reach the development backend during local testing. Not used in production builds. |

iOS App Tracking Transparency (ATT) does **not** apply to us — the Service does not track you across other apps or websites — so the app does not present the ATT prompt.

---

## 9. Cookies and similar technologies

The **admin web dashboard** (Next.js, served at the admin domain) uses:

* **First-party storage** — `localStorage` to hold the admin JWT (`token` for a tenant admin, `super_admin_token` for the platform Super-Admin). No cookies are set for the API.
* **No third-party trackers, no analytics cookies, no advertising cookies.**

The admin dashboard does **not** load any third-party JavaScript beyond Next.js framework bundles. The login and dashboard pages do not include Google Analytics, Meta Pixel, Hotjar, Segment, or similar trackers.

---

## 10. International transfers and storage location

Personal Data is held primarily in databases provisioned in regions chosen at the time the platform was deployed. Some sub-processors (Firebase, Cloudinary) operate globally and may process data outside India in the course of providing their services.

Where transfers occur outside India, we ensure that:

* the transfer is permitted under §16 of the DPDP Act (the Central Government has not, as of the effective date of this Policy, notified any restricted territories); and
* the receiving sub-processor is bound by contract to maintain the same standard of protection as required by Indian law.

If the Central Government notifies a list of restricted territories under the DPDP Act, we will update this Policy and our sub-processor list to comply.

---

## 11. How long we keep your data (retention)

We retain Personal Data only for as long as we need it for the purposes set out in §5, or for as long as required to comply with law. The default schedules are:

| Category | Retention |
|---|---|
| Account profile, household, vehicles | While your account is active; for **30 days** after deletion to allow audit reversal, then permanently erased except where required by law. |
| Visitor and gate-activity logs | **24 months** from the date of the visit, then permanently erased. The Society may shorten this. |
| Maintenance bills, payment records, receipts | **8 years** to satisfy applicable tax / book-keeping requirements (Section 128 of the Companies Act, 2013 and equivalent obligations for societies). |
| Complaints, notices, polls | **24 months** after resolution / closure. |
| Incidents, SOS alerts, SOC broadcasts, patrol logs | **36 months** for safety-incident reconstruction. |
| Push devices | Until the token is reported as invalid by FCM (auto-cleanup) or you sign out — whichever is earlier. |
| `AdminAuditLog` | **36 months**, then archived in a write-only sink for **24 additional months** before erasure. |
| Server access logs | **90 days**. |
| Cloudinary-hosted profile photos | Deleted when you remove your photo or your account is deleted (permanent deletion on Cloudinary follows within 30 days). |

After the periods above, data is either permanently deleted, or — where deletion is technically infeasible (immutable backups) — placed beyond use and overwritten with the next backup-rotation cycle (typically within **35 days**).

---

## 12. Security

We follow the requirements of Rule 8 of the IT (RSP) Rules, 2011 and §8(5) of the DPDP Act, including:

* **Encryption in transit** — all client ↔ API and admin ↔ API traffic is TLS 1.2+. The mobile app pins its API base URL via build-time configuration; `usesCleartextTraffic` is enabled only for development on a LAN host.
* **Encryption at rest** — managed by our database and storage sub-processors.
* **Password hashing** — bcrypt with cost factor 10. We never log or store plaintext passwords.
* **Session tokens** — short-lived JWTs verified on every API call; tenant clients additionally send `X-Society-Id`, which is cross-checked against the JWT's `societyId` at the auth-middleware layer.
* **Role-based access control** — `SUPER_ADMIN`, `ADMIN`, `RESIDENT` and `GUARD` are enforced server-side; `SUPER_ADMIN` cannot reach tenant routes.
* **Tenancy isolation** — every tenant query is filtered by `societyId`; archived Societies (`archivedAt != null`) block every tenant role at the auth layer.
* **Webhook authenticity** — billing webhooks from **Razorpay** and **PhonePe** verify cryptographic signatures (`X-Razorpay-Signature` HMAC against `RAZORPAY_WEBHOOK_SECRET`; PhonePe callback signature per their spec) before any ledger work runs.
* **Distributed-lock-protected cron jobs** — billing-cycle reconciliation uses a Postgres advisory lock so duplicate replicas cannot double-charge.
* **Defence in depth** — Multer file-size limits on uploads, Zod validation on every request body, and Prisma parameterised queries to prevent injection.
* **Vulnerability management** — CI runs dependency typechecks, lint, tests, and a `verify:migrations-safe` step that blocks `DROP TABLE` / `TRUNCATE` migrations without explicit allow-listing.
* **Incident response** — we follow CERT-In Cyber Security Directions, 2022, and will report reportable incidents to CERT-In within six hours of detection, and notify affected Data Principals and the Data Protection Board of India "without delay" as required by §8(6) of the DPDP Act, with sufficient detail to enable mitigation.

No system is perfectly secure. If you believe your account has been compromised, write to **divine.drwa@gmail.com** immediately.

---

## 13. Children's data

The Service is intended for adults who are members of a housing society, and for staff (Guards, Admins) authorised by the society.

* We do **not** knowingly process Personal Data of a child (under 18 in India) other than the minimal identifier of a child shown as a Family Member by a Resident (name, age, relationship). These items are entered voluntarily by the parent or guardian who holds the Resident account, and are visible only inside the Society.
* We do **not** profile, target advertising at, or behaviourally monitor any child.
* We do **not** process the data of a person with a disability who has a lawful guardian without verifiable consent of that guardian.

If you believe a child's data is being processed without proper consent, write to us at **divine.drwa@gmail.com** and we will erase the records within 7 working days unless we are required to retain them by law.

---

## 14. Your rights as a Data Principal

Under the DPDP Act you have the following rights, which you can exercise free of charge by writing to **divine.drwa@gmail.com**:

| Right (DPDP §) | What it means here |
|---|---|
| §11 — Right to information about processing | You can request a summary of the Personal Data we hold about you, the purposes of processing, and the categories of third parties we share it with. |
| §12 — Right to correction, completion, updating and erasure | Most fields are editable in **Settings → Profile**. For fields the Admin owns (e.g., move-in date), ask your Society. For erasure, see §15 below. |
| §13 — Right to grievance redressal | See §16 below. We will resolve grievances within 15 (fifteen) days of receipt. |
| §14 — Right to nominate | You can nominate, in writing, another individual to exercise these rights in the event of your death or incapacity. |
| Withdraw consent (§6(4)) | You can withdraw consent at any time. Withdrawal will not affect the lawfulness of processing carried out before the withdrawal. Some withdrawals (e.g., for push notifications) are wired to a self-service toggle in **Settings → Notifications**. |

You also have rights under the IT Act and rules, including the right to access your information collected as "SPDI" (Rule 5(6) of the RSP Rules) and to opt out of providing certain SPDI for non-mandatory purposes.

If you are located in the EEA / UK at the time you use the Service, we will additionally honour your applicable GDPR / UK-GDPR rights of access, rectification, erasure, restriction, portability and objection on a best-effort basis even though the Service is not targeted at the EEA / UK.

### 14.1 Your duties as a Data Principal (DPDP Act §15)

The DPDP Act also places certain duties on you when you use the Service. You agree to:

* comply with applicable law while exercising your rights under this Policy;
* **not impersonate** another person when providing your Personal Data;
* **not suppress** any material information when providing Personal Data for any document, unique identifier, proof of identity or address issued by the State;
* **not register a false or frivolous** grievance or complaint; and
* furnish only **information that is verifiably authentic** when exercising your right to correction or erasure.

Filing a false or frivolous grievance may attract the penalty prescribed under the DPDP Act.

---

## 15. Account deletion and data deletion

You have a one-click path to delete your account and request deletion of your Personal Data. Choose whichever is convenient:

* **In the mobile app:** **Settings → Account → Delete account**. The app will ask you to re-authenticate. On confirmation, your account is immediately deactivated; deletion completes asynchronously within **30 days** subject to the retention periods in §11.
* **In the admin web app:** **Profile menu → Delete account**.
* **By email:** write to **divine.drwa@gmail.com** from the email address registered on your account.
* **Without keeping the app installed:** send a deletion request from the email you registered with, to **divine.drwa@gmail.com**, with the subject line "GatePass+ account deletion request". We will respond within 24 hours.

When you delete your account:

* All Personal Data covered by §11 is erased on the timelines in §11.
* Society-level records that mention you only by your unit (e.g., a poll vote tied to your villa, a payment receipt for the villa, a notice published to your unit) are **retained** by the Society as anonymised records of building operations or as required for book-keeping; your name and identifiers are dissociated.
* Aggregated, anonymous analytics (Firebase Analytics) are retained.

We publish the same deletion path on a public URL satisfying Google Play's policy for app account deletion: please write to **divine.drwa@gmail.com** from a public computer if you cannot install the app.

---

## 16. Grievance redressal

If you have any complaint about how we process your Personal Data, or about content or conduct on the Service, you may write to:

> **Grievance Officer**
> GatePass+
> Email: **divine.drwa@gmail.com**

We will:

1. **Acknowledge** your complaint within **24 hours** of receipt;
2. **Resolve** the complaint within **15 (fifteen) days** of receipt (the period prescribed by Rule 5(9) of the IT (RSP) Rules and Rule 3(2)(c) of the IT (Intermediary Guidelines) Rules); and
3. Keep an audit trail of the complaint and resolution under §4.9.

If you are unsatisfied with our response, you may approach the **Data Protection Board of India** under §27 of the DPDP Act once it is operational.

---

## 17. Google Play Data safety mapping

We disclose the following on the Google Play Data safety form, which you can review on the Play Store listing:

| Play category | Data type | Collected | Shared | Purpose | Optional |
|---|---|---|---|---|---|
| Personal info | Name, email, phone | Yes | Sub-processors only | Account management, communications | No |
| Personal info | Address (only the Society / villa identifier) | Yes | Sub-processors only | Account management | No |
| Photos and videos | Photos (profile, complaint, visitor, incident) | Yes | Sub-processors only | App functionality | Yes |
| App activity | In-app actions; search history (not collected); installed apps (not collected) | App actions only | Sub-processors only | Analytics, app functionality | Optional |
| App info and performance | Crash logs, diagnostics | Yes | Sub-processors only | App functionality | No |
| Device or other IDs | FCM token, internal device id | Yes | Sub-processors only | Push delivery | No |
| Financial info | Gateway transaction metadata (Razorpay / PhonePe order or payment reference, amount, status) | Yes | Razorpay, PhonePe | Maintenance billing | Optional (you may pay offline) |

Data is **encrypted in transit** and we provide an in-app and email channel for **data deletion**. We commit to the Play Families Policy and the Developer Program Policies.

---

## 18. Apple App Store privacy nutrition mapping

The corresponding Apple "App Privacy" disclosures show:

* **Data Linked to You:** Contact Info (name, email, phone), Identifiers (FCM token, internal device id), User Content (photos, complaints), Financial Info (gateway transaction metadata from Razorpay or PhonePe — not raw card / UPI PIN / CVV).
* **Data Not Linked to You:** Diagnostics, App-functionality usage counts.
* **Data Used to Track You:** **None.**

---

## 19. Changes to this Privacy Policy

We may update this Privacy Policy from time to time. When we do, we will:

* update the "Last updated" date at the top of this document;
* publish the revised policy in **Settings → Legal → Privacy Policy** inside the mobile app, and at the equivalent location on the admin web app; and
* for material changes, notify you by push notification or by email at least **30 days** before the changes take effect.

Continuing to use the Service after a change becomes effective constitutes acceptance of the revised Policy.

---

## 20. Operator information and contact

| | |
|---|---|
| Service | **GatePass+** — housing-society operations platform for Divine Residency Welfare Association (DRWA) and other subscribing Resident Welfare Associations / housing societies |
| Application packages | Android `com.app.gatepass` · iOS `com.app.gatepass` |
| Privacy / grievance email | **divine.drwa@gmail.com** |
| Public Privacy Policy | **https://divinedrwa.github.io/GatePass-Legal/privacy_policy.html** |
| Public Terms & Conditions | **https://divinedrwa.github.io/GatePass-Legal/terms_condition.html** |
| Account deletion | **https://divinedrwa.github.io/GatePass-Legal/account_deletion.html** |
| Hours of response | Monday – Saturday, 10:00 – 18:00 IST (excluding public holidays) |

---

*This Privacy Policy is published in English. In case of any inconsistency between this English version and a translation, the English version will prevail.*
