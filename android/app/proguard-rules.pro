# ── Gson / TypeToken ─────────────────────────────────────────────────────────
-keep class * extends com.google.gson.reflect.TypeToken { *; }
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# ── flutter_local_notifications ───────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# ── Firebase ─────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Kotlin coroutines ────────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# ── Flutter engine ───────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── Adhan prayer times library ───────────────────────────────────────────────
-keep class com.batoulapps.adhan.** { *; }
-dontwarn com.batoulapps.adhan.**

# ── WorkManager ──────────────────────────────────────────────────────────────
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# ── App components (manifest-registered — names must survive obfuscation) ────
-keep public class com.aura.hala.MainActivity
-keep public class com.aura.hala.AdhanFullScreenActivity
-keep public class com.aura.hala.FocusModeActivity
-keep public class com.aura.hala.AuraAccessibilityService
-keep public class com.aura.hala.PrayerForegroundService
-keep public class com.aura.hala.FocusModeService
-keep public class com.aura.hala.PrayerAlarmReceiver
-keep public class com.aura.hala.DailySummaryReceiver
-keep public class com.aura.hala.JumuahReminderReceiver
-keep public class com.aura.hala.PrayerBootReceiver
-keep public class com.aura.hala.FocusModeReceiver
-keep public class com.aura.hala.StopAdhanReceiver
-keep public class com.aura.hala.ToggleSilentModeReceiver
-keep public class com.aura.hala.SilentOffReceiver
-keep public class com.aura.hala.DailyRecalcReceiver
-keep public class com.aura.hala.PrayerRescheduleService

# ── Enum values (needed for serialisation) ───────────────────────────────────
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
