package com.aura.hala

import android.content.Context
import android.util.Log
import com.google.firebase.auth.FirebaseAuth

/**
 * F70 session gate (decision D1-C, docs/designs/fix-f70-logout-alarms.md): native code may arm alarms and start
 * the foreground service only while a session exists, that is a guest session (`flutter.is_guest`) or a signed-in
 * Firebase user. No new pref: the gate flips by itself when `signOut()` completes and when a guest or login starts.
 *
 * Fail-open: when the Firebase read throws or the SDK is not ready the answer is "active". Switching a real user's
 * prayer alarms off by mistake is worse than leaving a signed-out user's alarms armed.
 */
object SessionState {
    private const val TAG = "SessionState"

    /** Pure decision. [hasUser] is null when the Firebase read failed (unknown, fail-open). */
    fun shouldArm(isGuest: Boolean, hasUser: Boolean?): Boolean = isGuest || hasUser != false

    /** Reads the existing state and logs the decision (the device check reads this line from logcat). */
    fun isSessionActive(context: Context, caller: String): Boolean {
        val isGuest = try {
            FlutterPrefs.getBoolean(context, "is_guest", false)
        } catch (e: Exception) {
            Log.e(TAG, "❌ [SESSION] is_guest read failed: ${e.message}")
            false
        }
        val hasUser: Boolean? = try {
            FirebaseAuth.getInstance().currentUser != null
        } catch (e: Throwable) {
            Log.e(TAG, "❌ [SESSION] currentUser read failed (fail-open): ${e.message}")
            null
        }
        val active = shouldArm(isGuest, hasUser)
        Log.d(
            TAG,
            "🔐 [SESSION] gate caller=$caller active=$active isGuest=$isGuest currentUserNull=${hasUser?.not() ?: "unknown"}"
        )
        return active
    }
}
