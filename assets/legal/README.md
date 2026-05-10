# In-app legal assets

These Markdown files are bundled in the app (`pubspec.yaml` → `assets/legal/`).

- Source of truth in the repo: `docs/legal/PRIVACY_POLICY.md` and `docs/legal/TERMS_AND_CONDITIONS.md`
- When you update the legal text, copy the files here (or keep them identical):

```bash
cp docs/legal/PRIVACY_POLICY.md divine_app/assets/legal/privacy_policy.md
cp docs/legal/TERMS_AND_CONDITIONS.md divine_app/assets/legal/terms_and_conditions.md
```

Optional: open a hosted policy URL instead of the bundle by building with:

`--dart-define=PRIVACY_POLICY_URL=https://...` and `--dart-define=TERMS_CONDITIONS_URL=https://...`

(See `AppConstants.privacyPolicyPublicUrl` / `termsConditionsPublicUrl`.)
