# GatePass+ Guard demo — exact app script (~80 sec)

Record with a **Guard** account assigned to a gate.  
**Before recording:** create one pre-approval from resident flow so **Pre-approved visitors** list is not empty.

**Prerequisite:** Resident script completed → QR visible on **Visitor pre-approved** success screen.

---

## Navigation map

| Step | Route | Screen file |
|------|-------|-------------|
| Guard home | `/guard/dashboard` | `guard_dashboard_page.dart` |
| QR scan | `/guard/scan-qr` | `guard_qr_scan_screen_io.dart` |
| Walk-in | `/guard/add-visitor` | `guard_check_in_screen.dart` |
| Pre-approved list | `/guard/pre-approved` | `guard_pre_approved_list_page.dart` |
| Bottom tabs | Home · **Active** · **Logs** · **Profile** | `guard_navigation_shell.dart` |

---

## Shot-by-shot (exact UI strings)

| Time | You tap / show | On-screen text to capture |
|------|----------------|---------------------------|
| **0:00** | Log in as **Guard** | Bottom nav loads **Security · Gate** app bar |
| **0:04** | Guard **dashboard** | Hero + summary strip (today’s visitors) |
| **0:08** | Section **Quick actions** | **Add visitor** · **Scan QR** · **Delivery** · **Emergency** · **Pre-approved** · **Patrol** |
| **0:12** | Tap **Scan QR** | Full-screen camera · title **Scan QR** · hint **Hold steady inside frame** · *Good lighting scans faster.* |
| **0:18** | Scan resident’s pre-approve **QR code** | Success / admit animation (whatever your app shows post-scan) |
| **0:24** | Back to dashboard · tap **Add visitor** | App bar **Add visitor** |
| **0:28** | **Visitor category** section | Pick category (guest / delivery / etc.) |
| **0:32** | **Contact** — **Mobile number** · **Full name** | *Phone first — guards verify quickly outdoors* |
| **0:38** | **Visiting resident** — search | Hint **Name, flat number, or block…** · select a resident |
| **0:44** | Scroll · tap **Confirm check-in** | Dialog **Confirm check-in** → **Check in** |
| **0:50** | Back · tap **Pre-approved** quick action | Title **Pre-approved visitors** |
| **0:56** | Tap a listed visitor · admit | (Use list from resident pre-approve) |
| **1:02** | Bottom tab **Active** | `/guard/entries` — active visitors inside society |
| **1:06** | Bottom tab **Logs** | `/guard/logs` — visitor log history |
| **1:10** | End card | **GatePass+** · **Security · Gate** · Play Store link |

---

## Voiceover (optional)

> "GatePass+ **Security · Gate** dashboard.  
> **Scan QR** — **Hold steady inside frame** — instant verify.  
> Walk-in? **Add visitor**, enter **Mobile number**, select **Visiting resident**, **Confirm check-in**.  
> Expected guests appear under **Pre-approved visitors**.  
> Track everyone under **Active** and **Logs**.  
> **GatePass+** for guards — download on Google Play."

---

## Pair with resident video

1. Record resident **QR code** screen first (freeze frame or second phone).  
2. Guard **Scan QR** uses that code — proves end-to-end GatePass+ flow.

---

## Guard UI accents (for editor)

- Guard mode uses **GuardTokens** palette (distinct from resident navy home).  
- App bar icon: shield · title **Security · Gate**
