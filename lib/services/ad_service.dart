import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized AdMob management: initialization, ad unit IDs, banner/native
/// ad creation, and interstitial loading + frequency-capped display.
///
/// ============================================================
///  REPLACE THESE TEST IDS WITH YOUR REAL ADMOB IDS BEFORE RELEASE
/// ============================================================
/// Everything below marked "TEST ID" is a Google-provided sample ad unit
/// that always serves test ads. Swap each for your own AdMob unit ID
/// (from admob.google.com) once you're ready to go live. Also remember to
/// replace the AdMob App ID in AndroidManifest.xml (see README notes).
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ---- App ID (set in AndroidManifest.xml, shown here for reference) ----
  // TEST APP ID: ca-app-pub-3940256099942544~3347511713
  // TODO: Replace with your real AdMob App ID in android/app/src/main/AndroidManifest.xml

  // ---- Banner (Scanner tab + History/Generator tab) ----
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/9214589741'; // TEST ID (Adaptive Banner)
    }
    return 'ca-app-pub-3940256099942544/2435281174'; // TEST ID (iOS banner, if you add iOS)
  }

  // ---- Interstitial (shown on "Open in Browser" / "Copy" actions) ----
  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // TEST ID
    }
    return 'ca-app-pub-3940256099942544/4411468910'; // TEST ID
  }

  // ---- Native Ad (embedded inside the Result screen card) ----
  static String get nativeAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/2247696110'; // TEST ID
    }
    return 'ca-app-pub-3940256099942544/3986624511'; // TEST ID
  }

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }

  // ------------------------------------------------------------------
  // Interstitial ad handling with frequency capping (max once per 3
  // "trigger actions" — e.g. Open in Browser / Copy to Clipboard taps).
  // ------------------------------------------------------------------
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  static const _kActionCountKey = 'ad_action_count_since_last_interstitial';
  static const int _frequencyCap = 3; // show interstitial every 3rd action

  void preloadInterstitial() {
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed to load: $error');
          _interstitialAd = null;
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  /// Call this whenever the user performs an ad-eligible action
  /// ("Open in Browser" or "Copy to Clipboard"). Internally tracks how many
  /// such actions have happened and only *shows* an interstitial once every
  /// [_frequencyCap] actions, so the user isn't bombarded on every tap.
  Future<void> maybeShowInterstitial() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_kActionCountKey) ?? 0) + 1;

    if (count >= _frequencyCap) {
      await prefs.setInt(_kActionCountKey, 0);
      await _showInterstitialNow();
    } else {
      await prefs.setInt(_kActionCountKey, count);
    }
  }

  Future<void> _showInterstitialNow() async {
    final ad = _interstitialAd;
    if (ad == null) {
      // Not ready yet (e.g. slow network) — silently skip this cycle
      // rather than blocking the user's action. Preload for next time.
      preloadInterstitial();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        preloadInterstitial(); // warm up the next one
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        preloadInterstitial();
      },
    );

    await ad.show();
  }

  // ------------------------------------------------------------------
  // Banner ad factory helper
  // ------------------------------------------------------------------
  BannerAd createAdaptiveBannerAd({
    required int width,
    required void Function(Ad ad) onLoaded,
    required void Function(Ad ad, LoadAdError error) onFailed,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize(width: width, height: 50),
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: onFailed,
      ),
    );
  }

  // ------------------------------------------------------------------
  // Native ad factory helper
  // ------------------------------------------------------------------
  NativeAd createNativeAd({
    required void Function(Ad ad) onLoaded,
    required void Function(Ad ad, LoadAdError error) onFailed,
  }) {
    return NativeAd(
      adUnitId: nativeAdUnitId,
      request: const AdRequest(),
      // "listTile" is a built-in factory template ID. On Android you must
      // register a matching NativeAdFactory in MainActivity.kt — see the
      // comment block at the bottom of this file for the exact code.
      factoryId: 'listTile',
      listener: NativeAdListener(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: onFailed,
      ),
    );
  }

  void disposeInterstitial() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}

/// ============================================================
/// ANDROID NATIVE AD FACTORY — required native-side registration
/// ============================================================
/// Native ads render through platform views, so Android needs a small
/// Kotlin factory that maps `factoryId: 'listTile'` to a real layout.
///
/// 1) Create `android/app/src/main/res/layout/list_tile_native_ad.xml`
///    with a NativeAdView containing headline/body/icon/CTA views.
///
/// 2) In `android/app/src/main/kotlin/.../MainActivity.kt`:
///
/// ```kotlin
/// import io.flutter.embedding.android.FlutterActivity
/// import io.flutter.embedding.engine.FlutterEngine
/// import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
///
/// class MainActivity : FlutterActivity() {
///     override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
///         super.configureFlutterEngine(flutterEngine)
///         GoogleMobileAdsPlugin.registerNativeAdFactory(
///             flutterEngine,
///             "listTile",
///             ListTileNativeAdFactory(layoutInflater)
///         )
///     }
///
///     override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
///         super.cleanUpFlutterEngine(flutterEngine)
///         GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "listTile")
///     }
/// }
/// ```
///
/// See the `google_mobile_ads` package README ("Native Ad Examples") for
/// the full `ListTileNativeAdFactory` Kotlin implementation reference.
