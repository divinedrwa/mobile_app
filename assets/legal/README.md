# In-app legal assets

These Markdown files are bundled in the app (`pubspec.yaml` → `assets/legal/`).

- Source of truth in the repo:
  - `docs/legal/PRIVACY_POLICY.md`
  - `docs/legal/TERMS_AND_CONDITIONS.md`
  - `docs/legal/ACCOUNT_DELETION.md`   ← also rendered as `account_deletion.html`
- When you update the legal text, copy the files here (or keep them identical):

```bash
cp docs/legal/PRIVACY_POLICY.md          divine_app/assets/legal/privacy_policy.md
cp docs/legal/TERMS_AND_CONDITIONS.md    divine_app/assets/legal/terms_and_conditions.md
```

Optional: open a hosted policy URL instead of the bundle by building with:

```
--dart-define=PRIVACY_POLICY_URL=https://...
--dart-define=TERMS_CONDITIONS_URL=https://...
--dart-define=ACCOUNT_DELETION_URL=https://...
--dart-define=SUPPORT_EMAIL=support@yourdomain
```

(See `AppConstants.privacyPolicyPublicUrl`, `termsConditionsPublicUrl`,
`accountDeletionPublicUrl`, and `supportEmail`.)

## Publishing the public account-deletion URL

Google Play's **User Data policy** requires a publicly-accessible URL
where prospective users can find deletion instructions before installing
the app. Drop `docs/legal/account_deletion.html` into the
`divinedrwa.github.io/GatePass-Legal` repository alongside the existing
HTML policy pages and submit
`https://divinedrwa.github.io/GatePass-Legal/account_deletion.html` in
Play Console → Store listing → Data safety.
