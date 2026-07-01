# GatePass+ Resident demo — exact app script (~95 sec)

Record on a **real build** (v1.1.14+) with a society that has **pending maintenance** and **payment methods** enabled.

**Demo data suggestion**
- Visitor: `Rahul Demo` · `9876543210` · Guest · Purpose: `Family visit`
- Do **not** complete a real payment on production — stop at **Choose payment method** or use test Razorpay if configured.

---

## Navigation map (exact routes)

| Step | Route / screen | File |
|------|----------------|------|
| Home | `/resident` tab **Home** | `home_screen.dart` |
| Visitor hub | `/resident/visitor-hub` | `visitor_hub_screen.dart` |
| Pre-approve | `/resident/pre-approve-visitor` | `pre_approve_visitor_screen.dart` |
| Success + QR | `VisitorSuccessScreen` | `visitor_success_screen.dart` |
| Maintenance hub | `/resident/maintenance` | `maintenance_hub_screen.dart` |
| Pay methods | `/resident/maintenance/pay` | `payment_method_selection_screen.dart` |

---

## Shot-by-shot (show these exact UI strings on screen)

| Time | You tap / show | On-screen text to capture |
|------|----------------|---------------------------|
| **0:00** | Open app → **Home** tab | Society name header · hero card **GatePass+** · subtitle **Visitor Management** |
| **0:05** | Tap hero **GatePass+** card | Opens **Visitors** · subtitle **Manage your guests and gate passes** |
| **0:10** | Pause on hub | **Today's summary** chips: **Visitors** / **Inside** / **Completed** |
| **0:14** | Scroll to **Quick Actions** | Tiles: **Invite Guest** · **Pre-Approve** · **Gate Requests** |
| **0:18** | Tap **Pre-Approve** (or **Invite Guest** — same flow) | App bar: **Add visitor** · **Create a pre-approved pass** |
| **0:22** | Step 1 — **Who is visiting?** | Pick **Guest** — *Friends, family, or social visitors* |
| **0:26** | Tap **Continue** | Step 2 — **Visitor details** |
| **0:30** | Fill **Full name** · **Mobile number** · **Purpose** | Labels exactly as on form |
| **0:36** | Tap **Continue** | Step 3 — **Schedule & preferences** · **Visit date** |
| **0:40** | Tap **Continue** | Step 4 — **Review & submit** · summary rows (Type, Name, Phone…) |
| **0:44** | Tap **Submit request** | Loading on bottom bar |
| **0:48** | Success screen | **Visitor pre-approved** · passcode · **QR code** · *Guards can scan this at the gate* |
| **0:54** | Tap **Share** or show **Copy** | Optional — shows passcode share |
| **0:58** | Back to **Home** → scroll to **Maintenance** card | Card shows **Due** / **Overdue** or amount · button **Pay** |
| **1:02** | Tap maintenance area → **Maintenance** hub | App bar title **Maintenance** |
| **1:06** | Hero card | Badge **Due** or **Overdue** · **Amount due** · **Due on** (cycle title e.g. June 2026) |
| **1:12** | Scroll to **Where your money goes** | Section title **Where your money goes** · donut · *Each society expense ÷ N billed homes* |
| **1:18** | Scroll to **Quick actions** | **My dues** · **My payments** · **Society expenses** |
| **1:22** | Tap sticky bottom **Pay ₹…** | Bar text **100% secure payments** · **UPI · Cards · Netbanking · Wallets** |
| **1:26** | **Choose payment method** screen | Title **Choose payment method** · **Select how you want to pay** · **Maintenance due: ₹…** |
| **1:32** | Highlight one method (Razorpay / UPI / PhonePe — whatever society has) | **Select a payment method** |
| **1:38** | End card (optional) | Logo **GatePass+** · **Reside. Approve. Manage.** · Play Store URL |

---

## Voiceover (optional — matches on-screen labels)

> "From Home, tap **GatePass+** — your **Visitor Management** hub.  
> Under **Quick Actions**, choose **Pre-Approve**.  
> Add a **Guest**, enter **Full name** and **Mobile number**, then **Submit request**.  
> Share the **QR code** — **Guards can scan this at the gate**.  
> For maintenance, open **Maintenance**, see **Amount due** and **Where your money goes**.  
> Tap **Pay ₹…**, then **Choose payment method** — UPI, Razorpay, or PhonePe when your society enables them.  
> **GatePass+** on Google Play."

---

## Do not show (wrong / internal)

- Admin tab unless demoing committee user  
- `/maintenance-payment` legacy screen (use **Maintenance** hub `/resident/maintenance`)  
- Society picker / login unless you want a 3-sec branded splash only  
