# GatePass+ — Google Play Store listing assets

Source-of-truth copy for the Play Console listing. Package: **`com.app.gatepass`**.

## Layout

```
store/play/
├── README.md
├── en-US/
│   ├── title.txt                 # Max 30 characters
│   ├── short_description.txt     # Max 80 characters
│   ├── full_description.txt      # Max 4000 characters
│   ├── promotional_text.txt      # Max 170 characters (optional in Console)
│   ├── whats_new_template.txt    # Release notes template
│   ├── store_listing_faq.md        # FAQ copy for support / Console
│   ├── screenshot_copy.md          # Headlines for screenshot designs
│   └── listing_metadata.json       # URLs, category, package reference
├── screenshots/                  # Phone screenshots (add PNGs here)
└── graphics/
    └── feature_graphic.png       # 1024×500 (add when ready)
```

## Upload to Play Console

1. Open [Google Play Console](https://play.google.com/console) → **GatePass+** (`com.app.gatepass`).
2. **Grow** → **Store presence** → **Main store listing**.
3. Set **Default language** to English (United States) if not already.
4. Copy/paste from `en-US/`:
   - **App name** ← `title.txt`
   - **Short description** ← `short_description.txt`
   - **Full description** ← `full_description.txt`
5. **Promotional text** (optional) ← `promotional_text.txt`
6. **Graphics**: upload phone screenshots to match `screenshot_copy.md`; feature graphic 1024×500 to `graphics/`.
7. **Store settings** → **App category**: House & Home (recommended).
8. **Policy** → link privacy URL from `listing_metadata.json`.

## Release notes

For each release, duplicate `whats_new_template.txt`, replace `{version}` and bullet points, paste under **Release** → **Production** → **Release notes**.

## Fastlane (optional)

These files map to Fastlane metadata if you add it later:

```
fastlane/metadata/android/en-US/title.txt          → copy from store/play/en-US/title.txt
fastlane/metadata/android/en-US/short_description.txt
fastlane/metadata/android/en-US/full_description.txt
```

## Before publishing

- [ ] Terms/Privacy mention online payments (Razorpay/PhonePe/UPI) if enabled in production.
- [ ] Play **Data safety** form matches actual data collection (payments, contacts, location if used).
- [ ] `pubspec.yaml` version matches the build you upload.
- [ ] Screenshots captured from the same build (currently **1.1.14+31** in repo).

## Character limits (verified)

| Field | Limit | Current file |
|-------|-------|----------------|
| Title | 30 | `title.txt` (28) |
| Short description | 80 | `short_description.txt` (74) |
| Promotional text | 170 | `promotional_text.txt` (144) |
| Full description | 4000 | `full_description.txt` (~2.1k) |
