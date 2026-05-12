# GatePass+ Theme System (Flutter)

A token-based theme system that lives in `lib/theme/`. Every colour, every
spacing unit, every border radius the app renders comes from this folder —
**zero `Color(0xFF…)` allowed outside `lib/theme/`**.

Goal: a future rebrand = edit one file (`app_colors.dart`) and every screen
updates atomically. The same token names exist in the web admin so Figma
specs read the same on both clients.

---

## File map

| File | What lives here |
|---|---|
| [`app_colors.dart`](app_colors.dart) | Private hex constants (`AppColorPalette.light` / `.dark`). Never imported by widgets. |
| [`app_typography.dart`](app_typography.dart) | Inter font, size scale (12/14/16/18/22/28/36/48), weight constants, `TextTheme`. |
| [`app_spacing.dart`](app_spacing.dart) | Raw spacing (4/8/12/16/24/32/48/64) and radius (sm/md/lg/full). |
| [`theme_extensions.dart`](theme_extensions.dart) | `ThemeExtension` classes: `BrandColors`, `SurfaceColors`, `TextColors`, `StateColors`, `AppSpacing`, `AppRadius`. |
| [`app_theme.dart`](app_theme.dart) | Builds `ThemeData` for light & dark from a palette. |
| [`theme_controller.dart`](theme_controller.dart) | Riverpod providers: `themeModeProvider` (Light/Dark/System) and `themeTokensProvider` (for future API-driven palette swaps). |
| [`context_extensions.dart`](context_extensions.dart) | `BuildContext` getters: `.brand`, `.surface`, `.text`, `.state`, `.spacing`, `.radius`. |
| [`theme.dart`](theme.dart) | Single public barrel — import this from `main.dart` and the app shell. |
| [`widgets/visitor_approval_card.dart`](widgets/visitor_approval_card.dart) | Reference card that uses every token category. |
| [`widgets/theme_mode_toggle.dart`](widgets/theme_mode_toggle.dart) | 3-way segmented Light / Dark / System control. |

---

## Wire into `MaterialApp`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/theme.dart';

class DivineApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final tokens = ref.watch(themeTokensProvider);

    return MaterialApp.router(
      theme: AppTheme.light(palette: tokens.light),
      darkTheme: AppTheme.dark(palette: tokens.dark),
      themeMode: mode,
      routerConfig: appRouter,
    );
  }
}
```

That's the only place either provider is consumed at app level. Every
widget downstream reads `context.brand`, `context.state`, etc.

---

## Use in a widget

```dart
import 'package:flutter/material.dart';
import '../../theme/context_extensions.dart';

class StatChip extends StatelessWidget {
  const StatChip({super.key, required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.s12,
        vertical: context.spacing.s8,
      ),
      decoration: BoxDecoration(
        color: context.state.info.bg,
        borderRadius: BorderRadius.circular(context.radius.sm),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: context.state.info.fg)),
          SizedBox(width: context.spacing.s8),
          Text('$value',
              style: TextStyle(
                color: context.state.info.fg,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}
```

Notice: **no** `Color(0xFF…)`, **no** raw `EdgeInsets.all(16)`, **no**
`isDarkMode ? ... : ...` branches. Dark theme just works because every
token reads from `Theme.of(context)`.

---

## Token reference

### Brand — `context.brand`

| | Light | Dark | Use for |
|---|---|---|---|
| `.primary` | `#0F172A` | `#F1F5F9` | App bar, page titles. |
| `.accent` | `#10B981` | `#34D399` | **Primary actions** ("Allow entry"). Matches the green `+` in the app icon. |
| `.danger` | `#EF4444` | `#F87171` | **Destructive actions** ("Block visitor"). Matches the barrier stripes in the app icon. |

### Surfaces — `context.surface`

| | Light | Dark |
|---|---|---|
| `.background` | `#FFFFFF` | `#020617` |
| `.defaultSurface` | `#F8FAFC` | `#0F172A` |
| `.elevated` | `#F1F5F9` | `#1E293B` |
| `.border` | `#E2E8F0` | `#334155` |

### Text — `context.text`

| | Light | Dark |
|---|---|---|
| `.primary` | `#0F172A` | `#F1F5F9` |
| `.secondary` | `#475569` | `#94A3B8` |
| `.tertiary` | `#94A3B8` | `#64748B` |
| `.inverse` | `#FFFFFF` | `#0F172A` |

### State — `context.state.{approved\|pending\|denied\|info}.{bg\|fg\|solid}`

| State | Light bg / fg / solid | Dark bg / fg / solid | Use for |
|---|---|---|---|
| `approved` | `#D1FAE5` / `#047857` / `#10B981` | `#064E3B` / `#6EE7B7` / `#34D399` | Visitor approved, transaction succeeded. |
| `pending` | `#FEF3C7` / `#92400E` / `#F59E0B` | `#78350F` / `#FCD34D` / `#FBBF24` | Visitor waiting for resident decision. |
| `denied` | `#FEE2E2` / `#991B1B` / `#EF4444` | `#7F1D1D` / `#FCA5A5` / `#F87171` | Visitor denied, payment failed. |
| `info` | `#DBEAFE` / `#1E40AF` / `#3B82F6` | `#1E3A8A` / `#93C5FD` / `#60A5FA` | Notices, hints. |

> `state.approved.solid` always equals the green `+` in the app icon.
> `state.denied.solid` always equals the barrier stripes in the app icon.

### Spacing — `context.spacing.{s4|s8|s12|s16|s24|s32|s48|s64}`
### Radius — `context.radius.{sm|md|lg|full}`

---

## How to add a token

1. Add the field on `AppColorPalette` in `app_colors.dart` (light + dark).
2. Add it to the relevant `ThemeExtension` class in `theme_extensions.dart`,
   wire `copyWith` and `lerp`, and update `.fromPalette()`.
3. Re-run `flutter analyze`. Any screen that ignored the token compiles
   unchanged because `Theme.of(context).extension<…>()!` returns the new
   instance.
4. Add the same token (with the same name) to `frontend/src/theme/tokens.ts`
   so the web admin stays in sync.

## How to change a colour

Open `app_colors.dart`. Change the hex value on `AppColorPalette.light`
or `.dark`. Run the app. Every screen reflects the change. Done.

> Re-validate WCAG AA contrast for every changed pair. Approved fg on
> approved bg must remain ≥ 4.5:1; brand text on brand surface ≥ 4.5:1;
> all of these were green-lit at the values shipped.

---

## Why hardcoding is forbidden

* **Atomic re-skin** — a `Color(0xFF…)` inside a feature widget is a
  rebrand blocker. One change to `app_colors.dart` must be enough.
* **Dark mode** — a hardcoded colour means *somebody* will forget to
  branch for dark mode and we'll ship a screen with white text on a white
  background.
* **API-driven theming** — once `themeTokensProvider.set(...)` swaps the
  active palette from an API response (white-labelled per Society),
  hardcoded colours simply will not update.

A CI step at `scripts/check_hardcoded_colors.sh` greps for `Color(0xFF`
outside `lib/theme/` and fails the build if it finds any. Hook it into
your pre-commit / CI lane to keep the rule enforced as the team grows.

---

## Future: API-driven theming

`themeTokensProvider` is already in place. To enable per-Society
white-labelling later:

```dart
final palette = await api.getThemeForSociety(currentSocietyId);
ref.read(themeTokensProvider.notifier).set(
  light: AppColorPalette(/* fields from API */),
  dark:  AppColorPalette(/* fields from API */),
);
```

`MaterialApp` rebuilds, every screen updates. No widget code touches the
new values — they were already reading from `Theme.of(context)`.
