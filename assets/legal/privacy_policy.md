# Privacy Policy

**Last updated:** May 6, 2026  

**Operator:** [YOUR_LEGAL_ENTITY_NAME] (“we”, “us”, “our”)  

**Contact:** [PRIVACY_EMAIL]  

**Website / App:** [PUBLIC_WEBSITE_URL]  

---

This Privacy Policy describes how we collect, use, store, share, and protect information when you use:

- **Resident / guard mobile application** (“Mobile App”),
- **Society administration web application** (“Admin Web”),
- **Related websites, APIs, and platform tools** (collectively, the “Services”),

which together support housing society operations (for example: visitors, security, notices, maintenance-related workflows, and society administration).

This document is prepared to align with common expectations for **Google Play User Data** transparency and **Google Play Data safety** disclosures. You must still complete Google Play’s **Data safety** form in Play Console accurately for your build and SDKs. See [Declare your app’s data use](https://developer.android.com/privacy-and-security/declare-data-use) and [Provide information for Google Play’s Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469).

> **Important:** This template is not legal advice. Have it reviewed by qualified counsel for your jurisdiction(s), especially if you process payments, children’s data, or health/safety-related information.

---

## 1. Who this policy applies to

Depending on your role, we process different categories of data:

| Role | Typical users |
|------|----------------|
| **Residents / household members** | People living in or associated with a villa/unit |
| **Guards / security staff** | Personnel performing gate or patrol duties |
| **Society administrators** | Authorized admins managing society operations |
| **Platform operators** (if enabled) | Internal staff operating multi-tenant tooling |

If your society enables optional modules (billing/payments, cloud media uploads, push notifications), additional processing may apply as described below.

---

## 2. Information we collect

We collect information **you provide**, **generated through use of the Services**, and **from your device** where necessary to operate features.

### 2.1 Account and identity information

- Name, username, email address, phone number  
- Role (for example: resident, guard, administrator)  
- Authentication secrets are stored using industry-standard password hashing on our servers; we do not store your password in plain text  
- Session tokens (for example JWT) used to keep you signed in securely  

### 2.2 Society and property context

- Society (community) identifier and society profile fields supported by the Services  
- Villa/unit identifiers and related operational attributes needed for society workflows  

### 2.3 Operational and safety-related information

Depending on enabled features, this may include:

- Visitor records (visitor identity fields as entered by users/guards, visit timestamps, approval status)  
- Gate / security event logs supported by the product  
- Parcel/logistics-style records if used by your society  
- Complaints/service requests and operational notes entered by users or admins  
- Notices and announcements published by authorized admins  

### 2.4 Maintenance and financial-related information (if enabled)

If your deployment enables maintenance billing or payments:

- Billing cycle metadata, payment status, invoice references, and payment logs needed to operate billing features  
- Payment processing may be handled by a third-party payment provider; we do not store full card numbers on our servers when payments are processed by the provider  

### 2.5 Media uploads (if enabled)

If your deployment uses image upload features (for example profile photos or attachments):

- Images/files you upload  
- Derived URLs or storage references returned by our processing pipeline  

### 2.6 Device and technical data

- Device type, OS version, app version (for compatibility and diagnostics)  
- Push notification tokens **if** push notifications are enabled (commonly via Firebase Cloud Messaging)  
- IP address and standard server logs (security, abuse prevention, troubleshooting)  
- Crash/diagnostic information if you enable diagnostic reporting  

### 2.7 Information we do not intend to collect

Unless a feature explicitly requires it and you grant permission in accordance with platform rules, we do not design the Services to collect:

- SMS/call logs  
- Your unrelated contacts directory  
- Precise location continuously in the background  

If you believe we have collected information inadvertently, contact us using **Section 11**.

---

## 3. How we use information

We use information to:

- Provide, operate, maintain, and improve the Services  
- Authenticate users and enforce role-based access controls  
- Facilitate society workflows you configure (visitors, notices, operational modules)  
- Send transactional notifications related to service operation (and push notifications if enabled and permitted)  
- Detect, prevent, and respond to fraud, abuse, and security incidents  
- Comply with legal obligations and enforce our Terms  

We apply **data minimization**: we process what is reasonably necessary for these purposes.

---

## 4. Legal bases (where applicable)

Depending on your region, our processing may be based on:

- **Performance of a contract** (providing the Services you/your society requested)  
- **Legitimate interests** (security, fraud prevention, service improvement), balanced against your rights  
- **Consent** (where required—for example certain notifications/marketing, if offered)  
- **Legal obligation** (where we must retain or disclose information by law)  

---

## 5. How we share information

We do not sell your personal information.

We may share information with:

### 5.1 Service providers (“processors”)

Vendors that help us host, secure, transmit, or operate the Services, for example:

- Cloud hosting / infrastructure providers  
- Database providers  
- Email/SMS delivery providers (if used)  
- Error monitoring / logging vendors (if enabled)  

We require service providers to protect information appropriately and use it only for the services they provide to us.

### 5.2 Payment processors (if payments are enabled)

Payments may be processed by a third-party payment gateway. Their privacy policy governs payment data processing directly with them.

### 5.3 Push notifications (if enabled)

Push delivery may use platform providers (for example Google/Firebase). Device tokens are processed to deliver notifications you expect from the Services.

### 5.4 Media processing (if enabled)

Image hosting/processing may use a third-party media provider configured for your deployment.

### 5.5 Society administrators

Certain information is intentionally visible to authorized administrators of your society to operate the community (for example operational records created within that society’s workspace).

### 5.6 Legal and safety

We may disclose information if required by law, regulation, legal process, or to protect the rights, safety, and security of users and the public.

### 5.7 Business transfers

If we are involved in a merger, acquisition, or asset sale, information may be transferred as part of that transaction, subject to appropriate safeguards.

---

## 6. International transfers

If your information is processed in countries other than your own, we implement appropriate safeguards as required by applicable law (for example contractual clauses), where applicable.

---

## 7. Data retention

We retain information as long as necessary to provide the Services and for legitimate business purposes, including:

- Security, audit, and dispute resolution  
- Compliance with legal obligations  

Retention periods may depend on society configuration, backups, and legal requirements. Some deletion requests may be limited where we must retain certain records.

---

## 8. Security

We implement reasonable administrative, technical, and organizational measures designed to protect information, including:

- Encryption in transit for browser/app traffic when configured with HTTPS/TLS  
- Access controls and authentication for administrative operations  
- Principle of least privilege for administrative roles  

No method of transmission or storage is 100% secure.

---

## 9. Your choices and rights

Depending on your jurisdiction, you may have rights to:

- Access, correct, update, or delete certain information  
- Object to or restrict certain processing  
- Withdraw consent where processing is consent-based  
- Lodge a complaint with a supervisory authority  

To exercise rights, contact **[PRIVACY_EMAIL]**. We may need to verify your identity.

---

## 10. Children’s privacy

The Services are intended for use under the direction of housing societies and adults authorized by the society. If you believe we have collected information from a child without appropriate authority, contact us and we will take appropriate steps.

---

## 11. Contact us

For privacy questions or requests:

- **Email:** [PRIVACY_EMAIL]  
- **Postal:** [LEGAL_POSTAL_ADDRESS] (optional)  

---

## 12. Changes to this policy

We may update this Privacy Policy from time to time. We will post the updated version with a new “Last updated” date (and, where required, provide additional notice).

---

## 13. Third-party policies you should review

These official references help you align store listings and in-product disclosures:

- Google Play: [User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311)  
- Google Play: [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469)  
- Android Developers: [Declare your app’s data use](https://developer.android.com/privacy-and-security/declare-data-use)  

---

## Appendix A — Inventory aligned with Google Play “Data safety” thinking

Use this appendix as an internal checklist when completing Play Console **Data safety**. Adjust checkboxes to match your actual production configuration.

**Data types commonly relevant for this product category**

- **Personal identifiers:** name, email, phone, account IDs  
- **Financial info:** billing/payment metadata if enabled (typically processed by payment providers)  
- **Photos / images:** if uploads are enabled  
- **App activity:** operational records created through normal use (visitor logs, notices, etc.)  
- **Device or other IDs:** push tokens; diagnostic identifiers as applicable  

**Processing purposes (examples)**

- App functionality  
- Analytics (only if you implement analytics)  
- Fraud prevention, security, compliance  
- Developer communications (only if you send product emails/SMS)  

**Security practices (examples you may declare if true)**

- Data encrypted in transit  
- Users can request deletion (if you offer it operationally)  

---

_End of Privacy Policy_
