# Quét QR Tpro — Setup & Release Guide

## 1. Create the project shell
```bash
flutter create --org com.yourcompany quet_qr_tpro
```
Copy everything from this delivery's `lib/`, `pubspec.yaml`, and `l10n.yaml`
into your new project (overwrite `main.dart` and `pubspec.yaml`). Then:
```bash
flutter pub get
```
`pubspec.yaml` has `generate: true`, so `flutter pub get` / `flutter run` /
`flutter build` automatically regenerates
`lib/l10n/generated/app_localizations.dart` from the two ARB files
(`lib/l10n/app_en.arb`, `lib/l10n/app_vi.arb`) — no manual codegen step.

## 2. Android configuration
- **Manifest**: merge `android_manifest_reference/AndroidManifest_snippet.xml`
  into `android/app/src/main/AndroidManifest.xml` (camera permission, AdMob
  App ID meta-data, internet permission, app label "Quét QR Tpro").
- **Native Ad factory**: merge `android_manifest_reference/MainActivity_reference.kt`
  into your `MainActivity.kt`. You still need to add:
  - `ListTileNativeAdFactory.kt` (Kotlin) — reference link is in that file's
    comments.
  - `res/layout/list_tile_native_ad.xml` — the native ad's visual layout.
- **build.gradle**: see `android_manifest_reference/build_gradle_snippet.txt`
  for `applicationId`, `minSdkVersion 21`, `multiDexEnabled`, and the
  release **signing config** block (required to publish — Play Store
  rejects unsigned/debug-signed release builds).
- **ProGuard/R8**: copy `android_manifest_reference/proguard-rules.pro` to
  `android/app/proguard-rules.pro` and enable `minifyEnabled true` in the
  release build type (already shown in the gradle snippet). Without these
  keep rules, ML Kit / AdMob can crash in release builds only.
- **App icon**: replace the default Flutter icon in
  `android/app/src/main/res/mipmap-*/ic_launcher.png` with your real logo,
  or use the `flutter_launcher_icons` package to generate all densities
  from one source image.

## 3. Localization (English + Vietnamese) — already wired up
- `lib/l10n/app_en.arb` / `app_vi.arb` hold every UI string.
- The app defaults to the **device's system language**, falling back to
  English if the device isn't set to English or Vietnamese.
- Users can manually override via the 🌐 globe icon on the Scanner screen
  (top-right) — the choice is remembered via `SharedPreferences`
  (`lib/services/locale_service.dart`).
- To add more strings later: add the key to both ARB files, then reference
  it via `AppLocalizations.of(context)!.yourKey`.
- To add a third language (e.g. `fr`): create `lib/l10n/app_fr.arb`, add
  `Locale('fr')` to `LocaleService.supportedLocales`.

## 4. Replace test Ad Unit IDs before release
All AdMob IDs in `lib/services/ad_service.dart` are Google's public TEST
IDs — safe for development, but **must be swapped for your real AdMob unit
IDs before publishing**:
- `bannerAdUnitId`, `interstitialAdUnitId`, `nativeAdUnitId`
- The `APPLICATION_ID` 