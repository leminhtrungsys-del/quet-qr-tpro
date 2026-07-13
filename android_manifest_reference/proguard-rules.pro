# Reference file — place at android/app/proguard-rules.pro and enable it
# via `minifyEnabled true` + `proguardFiles ... 'proguard-rules.pro'` in
# android/app/build.gradle (release buildType). Needed because R8/ProGuard
# can strip classes that ML Kit and AdMob load via reflection, causing
# crashes in release builds that don't reproduce in debug.

# --- Google ML Kit (barcode scanning) ---
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**

# --- Google Mobile Ads (AdMob) ---
-keep class com.google.android.gms.ads.** { *; }
-keep public class com.google.android.gms.ads.mediation.MediationAdapter
-keep public class com.google.android.gms.ads.mediation.customevent.CustomEventAdapter
-dontwarn com.google.android.gms.ads.**

# --- Hive (reflection-free, but keep TypeAdapter subclasses to be safe) ---
-keep class * extends com.google.gson.TypeAdapter
-keep class **.*Adapter { *; }

# --- General AndroidX / Kotlin metadata (avoids stripped annotations) ---
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
