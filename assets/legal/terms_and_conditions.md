# Terms and Conditions

**Service:** GatePass+ ("Service", "Platform", "we", "us", "our")
**Effective date:** 12 May 2026
**Last updated:** 12 May 2026
**Contact:** divine.drwa@gmail.com
**Governing law:** Republic of India

These Terms and Conditions (the **"Terms"**) constitute a binding legal agreement between **you** and **GatePass+** governing your access to and use of:

* the **GatePass+ mobile application** for Residents and Guards (Android package `com.app.gatepass`, iOS bundle `com.app.gatepass`);
* the **GatePass+ admin web dashboard** for society administrators;
* all related backend APIs, websites, documentation and support channels (collectively, the **"Service"**).

Please read these Terms carefully. **By installing the mobile app, creating an account, signing in, or otherwise using the Service, you confirm that you have read, understood and agree to be bound by these Terms and by our Privacy Policy.** If you do not agree, do not install or use the Service.

---

## 1. About the Service

GatePass+ is a housing-society operations platform that provides software to **Resident Welfare Associations**, **Apartment Owners' Associations**, housing co-operatives and similar communities (each, a **"Society"**) and their members. The Service helps a Society manage residents, gate security, visitors and deliveries, vehicles and parking, maintenance records, notices, polls, documents, complaints, amenity bookings, SOS / emergency response, and related operations.

GatePass+ is provided **purely as a technology platform**. **It is not** an emergency service, a security agency, a police service, a fire brigade, a medical-response service, a banking institution, a payment aggregator, a real-estate broker, or a property manager. **GatePass+ does not collect, process, or facilitate any online payments — see §6 below.**

---

## 2. Eligibility

You may use the Service only if **all** of the following are true:

1. You are at least **18 years old**, or you are using the Service under the supervision of a parent or legal guardian who has accepted these Terms on your behalf.
2. You have the **legal capacity** to enter into a binding contract under the Indian Contract Act, 1872, and you are not barred from receiving services under any applicable law.
3. You have been **invited or authorised by a Society** that subscribes to the Service, except for the Super-Admin role which is provisioned directly by us.
4. You agree to comply with all applicable laws and with any society-specific bye-laws or operational rules communicated to you.

If we discover that you do not satisfy any of the above, we may suspend or close your account.

---

## 3. Accounts and roles

### 3.1 Roles

The Service implements four roles:

| Role | Purpose |
|---|---|
| **Resident** | An adult member of a Society household using the mobile app to manage visitors, maintenance, complaints, etc. |
| **Guard** | A security staff member of a Society using the mobile app for gate operations, visitor logging, patrols and incident reporting. |
| **Admin** | A Society administrator (typically a managing-committee member or appointed staff) using the web dashboard to manage residents, maintenance records, notices and operations. |
| **Super-Admin** | A platform operator (employed or authorised by us) with permissions limited to creating, archiving, restoring and supporting Societies. Super-Admin **cannot** access tenant routes without explicit, audited delegation. |

### 3.2 Account creation

Most accounts are created by your Society's Admin or via an invitation token. You are responsible for the accuracy of the information you provide and for keeping it current.

### 3.3 Credentials

You must:

* keep your username and password **confidential**, store them only on devices that you personally control, and not share them with anyone (including other members of your household);
* enable biometric / device-passcode protection on the device you use to access the Service;
* **immediately** notify us at **divine.drwa@gmail.com** if you suspect that your credentials have been disclosed or that your account has been used by an unauthorised person;
* not maintain more than one Resident account in the same Society for the same individual.

You remain responsible for everything done through your account until you have notified us of a compromise and we have suspended access.

### 3.4 Society as your data administrator

Your account is provisioned within a **specific Society**. Your Admin can:

* view, edit or remove information about you that the Society holds for its operational records (such as your villa / unit assignment, move-in date, residency status);
* deactivate your account when you cease to be associated with the Society;
* publish notices, polls and bills addressed to you.

We follow the Admin's instructions for data scoped to the Society. If you disagree with an action your Admin has taken, raise it with the Admin first. You may also write to **divine.drwa@gmail.com** if you believe the action violates law or these Terms.

---

## 4. Acceptable use

You agree **not** to:

1. use the Service for any unlawful, fraudulent, harassing, defamatory, obscene, infringing, hateful or discriminatory purpose;
2. impersonate another person, misrepresent your role in a Society, or use the Service through an account that is not yours;
3. attempt to circumvent the role-based access controls, tenant isolation, rate limits, signed-payload checks or any other security mechanism in the Service;
4. probe, scan, penetration-test, reverse-engineer, decompile, disassemble or attempt to extract source code from the Service except to the limited extent permitted by §63(b) of the Copyright Act, 1957;
5. introduce malicious code, denial-of-service traffic, automated scrapers, scripted account creation, or any tool intended to interfere with the Service;
6. use the Service to send unsolicited commercial communications ("spam") to other users;
7. upload content that violates a third party's intellectual-property rights, privacy, or publicity rights;
8. upload Personal Data of another person without that person's consent (a particular note for visitor logging — Guards must inform visitors that their details are being recorded);
9. attempt to download or extract bulk Personal Data from the Service unless you are the lawful Society Admin doing so for the Society's own records;
10. use the Service for advertising, marketing automation, or political-campaign messaging unrelated to the Society's lawful affairs;
11. resell, sublicence, white-label, lease or otherwise commercially redistribute the Service without our written consent.

We may, at our sole discretion, remove content or suspend any account that we reasonably believe violates these Terms.

---

## 5. Visitor and gate operations

Guards record visitor details — name, phone number, purpose of visit, vehicle number and (optionally) a photo — at the gate of a Society. This is necessary for the Society to maintain a record of who entered the premises.

### 5.1 Visitor notice and consent

Each Society is required to:

* display **clear gate signage** at every entry / exit informing visitors that their details (including name, phone, vehicle number and, where applicable, photo) are recorded as a condition of entry; and
* ensure that Guards give a brief **verbal notice** to each visitor at the gate, in a language the visitor can reasonably understand, before recording their details.

**By entering the Society premises after such notice, the visitor is deemed to have given implied consent** to the collection, recording and processing of their visitor data as described in our Privacy Policy and the Society's own posted notice.

By recording such information you (the Guard, the Admin or the Resident initiating a pre-approval) confirm that the visitor has received the notice above and that you are not collecting data through coercion, deception or in violation of any law.

### 5.2 Pre-approved visits

Where a Resident pre-approves a visitor and generates an OTP, the Resident is responsible for sharing the OTP only with the intended visitor and only for the validity window shown in the app.

### 5.3 Approval timeliness

Multi-villa approval responses (approve / reject) are time-sensitive operational signals. **We make no guarantee that any specific approval will be reviewed within any specific timeframe.** Your Society sets its own approval mode (any-one approval or all-villas required).

---

## 6. No payment processing

**GatePass+ does NOT collect, process, or facilitate any online payments within the Service.**

* **No payment gateways** (Razorpay, PhonePe, Stripe, Paytm, Cashfree or any similar service) are integrated into the mobile app or the admin web dashboard.
* The Service does **not** handle or transmit any payment-instrument data — no card numbers, no CVVs, no UPI VPAs / handles, no net-banking credentials, no wallet identifiers, no one-time payment OTPs.
* GatePass+ does **not store, process, or have access to** any financial or payment-instrument information of users.
* No payment webhooks, gateway callbacks, settlement messages or chargebacks are routed through the Service.

### 6.1 How maintenance payments actually happen

All maintenance and other society-related payments are made **outside the Service**, directly between the Resident and the Society — typically by bank transfer, cheque, UPI to the Society's own account, or cash. The Society's bank-account details shown inside the app are the **Society's** information, displayed to Residents for their convenience.

### 6.2 Records of offline payments

After receiving a payment offline, the Society Admin may record an entry inside the admin dashboard so the Resident can see an acknowledgement. **Such an entry is a record only** — it is not a payment instruction, does not move any money, and creates no financial obligation between you and us.

### 6.3 Bill amounts and disputes are between you and your Society

Maintenance bills are issued by your **Society**, not by us. Bill amounts, due dates, components (sinking fund, common-area charges, penalties), late-fee rules, refund rules, grace periods and book-keeping treatment are determined by the Society and are governed by the Society's bye-laws or resolutions. **We are not a party to the underlying financial transaction.** Any dispute about a maintenance amount or a recorded payment is between you and your Society — raise it with your Society Admin first.

### 6.4 Future changes

If a future version of the Service adds any online-payment functionality, these Terms and our Privacy Policy will be updated in advance, the relevant payment-processor sub-processor will be added to the Privacy Policy, and the corresponding consent will be obtained from you before any such processing begins.

---

## 7. SOS and safety features — **important disclaimer**

The Service includes an **SOS / emergency-alert** feature that allows a Resident to notify Guards and Society Admins of a medical, fire, security or other emergency.

**The SOS feature is a notification tool, not an emergency service.**

* It does **not** dispatch ambulances, fire engines, the police or any other government emergency-response service.
* It delivers the alert over the public internet via push notifications; delivery is **not guaranteed** and can be delayed or fail because of network outages, device-side notification settings, OS-level battery optimisations, FCM throttling, or app uninstalls on responder devices.
* SOS responders are **personnel of your Society** acting in their personal capacity or under their employment with the Society. We do not employ, train, supervise, certify or vouch for them.
* The Service is **not a substitute for calling 112, 100, 101, 102, 108 or any other official emergency number** in India. **In any genuine emergency, dial the appropriate government helpline first.**

By using the SOS feature you confirm that you understand the limitations above and that you will exercise your own judgement.

---

## 8. Content rights

### 8.1 Content you submit

When you upload content into the Service (profile photo, complaint description, document, visitor photo, etc.), you keep ownership of your content. You grant us, your Society and our sub-processors a **non-exclusive, worldwide, royalty-free, sub-licensable licence** to host, store, transmit, display and process that content as needed to operate the Service and provide it to the people authorised to see it. This licence ends when you delete the content, except to the extent the content must be retained under the Privacy Policy retention schedule or by law.

### 8.2 Our content

The Service — including its source code, design, brand (the wordmark "GatePass+", the GatePass+ icon, the green "+" badge), database schema, documentation and outputs — is owned by us or licensed to us. You receive **no rights** in the Service other than the limited right to use it in accordance with these Terms.

### 8.3 Open-source notices

The Service includes open-source software released under various licences (including the MIT, Apache 2.0, BSD, and similar licences). The list of components and their licences is available on request to **divine.drwa@gmail.com**.

### 8.4 Feedback

If you send us feedback, suggestions, or proposals, we may use them without obligation to you. You confirm that any feedback you provide is given voluntarily and is not confidential.

---

## 9. Communications

By using the Service you consent to receive:

* **In-app notifications** (the `UserNotification` inbox);
* **Push notifications** if you have granted the OS permission (you can revoke this from OS settings or **Settings → Notifications** in the app);
* **Operational emails** about your account, bills, security alerts and material policy updates — at the email address registered on your account.

We do **not** send marketing communications today. If we introduce them in future, we will ask for separate consent.

---

## 10. Third-party services

The Service integrates with the sub-processors listed in the Privacy Policy (currently: **Neon** — managed PostgreSQL; **Render** — application hosting; **Cloudinary** — profile-photo storage; **Firebase Cloud Messaging** and **Firebase Analytics** — push delivery and aggregated analytics; **Apple** and **Google** — app distribution and push transport). When you use those features, you also accept the applicable third-party terms. We do not control and are not responsible for the content, policies or practices of any third party.

GatePass+ **does not** integrate any payment-gateway or payment-processor sub-processor (see §6).

---

## 11. Service availability, changes and beta features

* We work to keep the Service available, but we do not guarantee uninterrupted, error-free or timely access.
* We may add, modify, remove or temporarily suspend features without notice for routine maintenance, security, capacity, regulatory reasons or commercial reasons. For material adverse changes we will give reasonable advance notice through the app or by email where practicable.
* Some features may be marked as **beta** or **preview**. Beta features are provided "as is" and may be withdrawn or changed at any time.
* Backend infrastructure (Neon Postgres, Render, Cloudinary, Firebase) is subject to its providers' service-level commitments; we do not extend those commitments to you separately.

---

## 12. Suspension and termination

### 12.1 By you

You may stop using the Service at any time, sign out, uninstall the app, and request account deletion as described in §15 of the Privacy Policy.

### 12.2 By your Society

Your Society may deactivate your account when you cease to be a member, are otherwise no longer authorised to use the Service for that Society, or violate the Society's bye-laws.

### 12.3 By us

We may suspend or terminate your account, or your entire Society's tenant, immediately and without prior notice if:

* you violate these Terms or our Privacy Policy;
* we receive a credible report that you have used the Service to commit, attempt or facilitate fraud, harassment, or any criminal offence;
* a court, tribunal or government authority orders us to do so;
* continued operation poses a security risk to the Service or to other users; or
* your Society fails to pay subscription fees due to us (where applicable).

If a Society is suspended or archived (see `archivedAt` in our database), every tenant role inside that Society is blocked from signing in until the Society is restored or you have moved to a different Society's account.

### 12.4 Effect of termination

Upon termination, your right to access the Service ends immediately. Sections that by their nature survive termination — including §4 (Acceptable use), §8 (Content rights), §13 (Disclaimers), §14 (Limitation of liability), §15 (Indemnity), §17 (Governing law) and §19 (Survival) — will continue to apply.

---

## 13. Disclaimers

To the maximum extent permitted by law:

* **The Service is provided "as is" and "as available", without warranties of any kind**, express or implied, including implied warranties of merchantability, fitness for a particular purpose, accuracy, non-infringement, or that the Service will be uninterrupted or error-free.
* **GatePass+ acts solely as a technology provider** to your Society. We do not own, operate, manage or run the Society itself; we are not responsible for the actions, conduct, decisions, omissions or negligence of any Resident, Guard, Admin, vendor, contractor or visitor using the Service, nor for the operational, financial, legal or governance decisions of any Society.
* **All data displayed in the Service is based on input typed in by users, Guards or Admins and is not independently verified by us.** The Service displays what was entered; verification is the responsibility of the entering party and of the Society. You should not rely on any information shown in the Service as authoritative without confirming it with the source.
* **We are not responsible for any security incident occurring within or in connection with a Society** (for example, unauthorised entry, theft, property damage, personal injury, harassment, or fraud committed by any individual). The Service is a tool that supports a Society's own security and operational processes; **it does not replace** a Society's physical security, supervision, due diligence or governance.
* We make no warranty regarding the **identity** or trustworthiness of any visitor, vendor, domestic-staff member, contractor or other third party whose details are recorded in the Service.
* We make no warranty regarding the **outcome** of any complaint, poll, notice, maintenance dispute, vendor engagement or other Society operation that is communicated through the Service.
* Push notifications, including SOS alerts, are delivered over the public internet on a best-effort basis. We do not warrant their delivery, timing, or visibility on any specific device.

---

## 14. Limitation of liability

To the maximum extent permitted by law:

* In no event will we, our directors, employees, officers, agents or licensors be liable for any **indirect, incidental, special, consequential, exemplary or punitive damages**, including loss of profits, loss of goodwill, loss of data, business interruption, or any failure to deliver a notification on time.
* Our **aggregate liability** to you arising out of or in connection with the Service in any 12-month period will not exceed the lesser of (a) **₹5,000 (Indian Rupees five thousand only)** or (b) the total fees, if any, that you (and not your Society) actually paid to us for the Service in the same 12-month period.
* Nothing in these Terms excludes or limits liability for:
  - death or personal injury caused by our gross negligence or wilful misconduct;
  - fraud or fraudulent misrepresentation by us; or
  - any liability that cannot lawfully be excluded or limited under the laws of India.

The Service is sold to Societies on a B2B basis. Where you are an individual Resident or Guard using the Service on behalf of a Society at the Society's direction, you are not a "consumer" under the Consumer Protection Act, 2019 for the Service itself — your contract for the Service is between you and the Society. Consumer-protection rights for the underlying maintenance, amenities and security services delivered by the Society remain unaffected.

---

## 15. Indemnity

You agree to defend, indemnify and hold us harmless from and against any claim, demand, loss, liability, damage, fine or expense (including reasonable legal fees) arising out of or in connection with:

* your breach of these Terms or of any applicable law;
* content that you upload to the Service;
* your use of the Service in violation of a third party's rights (intellectual property, privacy, publicity, contract);
* any data you record about a visitor, family member, staff member or vendor without their lawful consent.

---

## 16. Reports of unlawful content (intermediary obligations)

We act as an **intermediary** under Section 79 of the Information Technology Act, 2000 for user-generated content. If you believe content on the Service is unlawful, infringing your intellectual-property rights, or otherwise violates these Terms, write to **divine.drwa@gmail.com** with:

1. your identity and contact details;
2. a clear description of the content (URL, screenshot, or in-app reference);
3. the reason the content is unlawful or infringing, with the specific law cited;
4. for IP claims, proof of your right and a good-faith statement that the disputed use is not authorised;
5. a statement that the information you provide is accurate, and that — for IP claims — you are the rights-holder or authorised to act for them.

We will act on lawful requests within **36 hours** as required by the IT (Intermediary Guidelines) Rules, 2021, and remove content for which a court order or appropriate government order is received.

---

## 17. Governing law and dispute resolution

### 17.1 Governing law

These Terms and any non-contractual obligation arising out of or in connection with them are governed by the **laws of the Republic of India**, without regard to its conflict-of-laws principles.

### 17.2 Step 1 — internal resolution

Before initiating any legal proceeding, you agree to:

1. raise the matter with your **Society Admin** if it relates to Society-level operations or billing;
2. write to **divine.drwa@gmail.com** with a full description of the dispute and the resolution you are seeking;
3. give us **30 days** from the date we acknowledge receipt to attempt a good-faith resolution.

### 17.3 Step 2 — mediation

If the matter is not resolved within Step 1, the parties will attempt to resolve it through **mediation** under the Mediation Act, 2023, with a sole mediator appointed by mutual agreement.

### 17.4 Step 3 — courts

Failing mediation, the dispute will be subject to the **exclusive jurisdiction of the courts at New Delhi, India**, except that we may seek interim or injunctive relief in any court of competent jurisdiction to protect our intellectual property or the security of the Service.

---

## 18. Notices

* **From us to you:** by email at the address on your account, by in-app notification, by push notification, or by posting on a public page of the Service.
* **From you to us:** by email to **divine.drwa@gmail.com**.

A notice is deemed delivered: by email — when sent, unless we receive a bounce; by in-app or push notification — when first displayed in the app; by post on a public page — 24 hours after posting.

---

## 19. Survival

The following provisions survive termination of these Terms: §4 (Acceptable use), §8 (Content rights), §13 (Disclaimers), §14 (Limitation of liability), §15 (Indemnity), §16 (Reports of unlawful content), §17 (Governing law and dispute resolution), §19 (Survival) and §20 (Miscellaneous).

---

## 20. Miscellaneous

### 20.1 Entire agreement

These Terms, the Privacy Policy and any in-product notices that we present to you (for example, the per-feature consents) constitute the **entire agreement** between you and us regarding the Service, and supersede any prior agreement.

### 20.2 Severability

If any provision of these Terms is held by a court of competent jurisdiction to be invalid, illegal or unenforceable, that provision will be enforced to the maximum extent permitted, and the remaining provisions will continue in full force and effect.

### 20.3 No waiver

Failure or delay by us to enforce any right under these Terms is not a waiver of that right.

### 20.4 Assignment

You may not assign or transfer your rights or obligations under these Terms without our prior written consent. We may assign or transfer our rights and obligations to an affiliate or in connection with a merger, acquisition, sale of assets or by operation of law, on prior notice to you.

### 20.5 Force majeure

We will not be liable for any failure or delay in performance caused by events beyond our reasonable control, including acts of God, internet outages, third-party service outages, governmental action, civil unrest, pandemic and labour disturbance.

### 20.6 Relationship

Nothing in these Terms creates any partnership, joint venture, agency, employment or fiduciary relationship between you and us. You may not bind us to any agreement with a third party.

### 20.7 Headings

Headings are for convenience only and do not affect the interpretation of these Terms.

### 20.8 Language

These Terms are published in English. In case of any inconsistency between this English version and a translation, the English version will prevail.

---

## 21. Changes to these Terms

We may update these Terms from time to time. When we do, we will:

* update the "Last updated" date at the top of this document;
* publish the revised Terms in **Settings → Legal → Terms and Conditions** inside the mobile app and at the equivalent location in the admin web app; and
* for material changes, notify you in the app or by email at least **30 days** before the changes take effect.

Continuing to use the Service after a change becomes effective constitutes acceptance of the revised Terms. If you do not agree to a change, you must stop using the Service and may request account deletion.

---

## 22. How to contact us

| | |
|---|---|
| Service | **GatePass+** — housing-society operations platform |
| Application packages | Android `com.app.gatepass` · iOS `com.app.gatepass` |
| Email (all matters, including grievance redressal) | **divine.drwa@gmail.com** |
| Response hours | Monday – Saturday, 10:00 – 18:00 IST (excluding public holidays) |
| Response timeline | Acknowledgement within 24 hours; substantive response within 15 days |

---

*Last updated: 12 May 2026.*
