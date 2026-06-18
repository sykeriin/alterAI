# Alter — Flutter (design source of truth)

**Canonical UI reference for the main app.** Screens, theme, and widgets here are the design
source; the production app wires the same layouts through [`lib/src/ui/`](../../lib/src/ui/)
with Riverpod + gateway providers.

When you change UI here, update the matching files under `lib/src/ui/` in the same change.

## Run

```bash
flutter pub get
flutter run
```

Requires **Flutter 3.27+ / Dart 3.6+** (the code uses the current `Color.withValues()`
API). Fonts (Space Grotesk + Manrope) are pulled at runtime via the
`google_fonts` package, so an internet connection is needed on first launch (or bundle the
fonts into `assets/` and switch `google_fonts` to offline mode for production).

## Structure

```
lib/
  main.dart                  App entry, routes, the FTUE → onboarding → app flow
  theme.dart                 Color tokens + text styles (Space Grotesk / Manrope)
  widgets.dart               Shared widgets: StarMark, Orb, GradientScaffold, chips, headers
  screens/
    ftue.dart                What is Alter · 5 feature pages (PageView) · Get Started
    onboarding.dart          Login · Languages · About You
    main_shell.dart          Persistent glass bottom-nav + Settings end-drawer
    dashboard.dart           Life Feed
    future.dart              Future hub (entries to Council / Simulator / Radar)
    voice.dart               Voice assistant (listening / speaking animations + Alter Lens)
    stats.dart               Reputation dashboard
    profile.dart             Profile · Social Graph / NFC entry
    deep.dart                Clone Council (carousel) · Future Simulator · Opportunity Radar
                             · Social Graph · Deep Analysis
    settings.dart            Settings slide-over (end-drawer) + Light/Dark toggle
```

## Light / Dark mode

The app ships in **dark** by default. Open **Settings** (gear, top-left of any primary
screen) → **Appearance** → toggle **Light / Dark**. The switch flips a global
`AlterTheme.isLight` notifier; the whole app rebuilds instantly:

- `AppColors.white(o)` drives all text + glass surfaces and flips white→ink.
- `GradientScaffold` keeps each screen's hue but swaps the dark base/mid stops for
  light neutrals, so every screen themes automatically.
- Bright accents (lime, purple, cyan…) and the glowing orbs stay identical in both modes.

## Navigation

- `FtueWhat → Features → GetStarted → Login → Languages → AboutYou → MainShell`
- `MainShell` hosts the 5 primary tabs in an `IndexedStack` with a custom glass pill nav.
- Deep screens (`CloneCouncil`, `FutureSimulator`, `OpportunityRadar`, `SocialGraph`,
  `DeepAnalysis`) are pushed routes. Settings is an end-drawer opened by the gear icon.
