package com.aura.hala

import android.content.Context
import android.content.SharedPreferences

/**
 * Access to the file the Flutter shared_preferences plugin actually uses:
 * "FlutterSharedPreferences", with every key prefixed "flutter.".
 *
 * "${packageName}_preferences" is NOT that file — reads from it always return
 * defaults and writes to it are invisible to Dart. Use this helper everywhere
 * native code needs a setting that Flutter saved, or needs to hand a value to
 * Dart through SharedPreferences.
 */
object FlutterPrefs {
    private const val FILE_NAME = "FlutterSharedPreferences"
    private const val KEY_PREFIX = "flutter."

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)

    fun getBoolean(context: Context, key: String, default: Boolean): Boolean =
        prefs(context).getBoolean(KEY_PREFIX + key, default)

    fun getString(context: Context, key: String, default: String): String =
        prefs(context).getString(KEY_PREFIX + key, default) ?: default

    fun getInt(context: Context, key: String, default: Int): Int =
        when (val v = prefs(context).all[KEY_PREFIX + key]) {
            is Long -> v.toInt()
            is Int -> v
            else -> default
        }

    fun putString(context: Context, key: String, value: String) {
        prefs(context).edit().putString(KEY_PREFIX + key, value).apply()
    }

    fun putBoolean(context: Context, key: String, value: Boolean) {
        prefs(context).edit().putBoolean(KEY_PREFIX + key, value).apply()
    }

    fun putInt(context: Context, key: String, value: Int) {
        // The plugin stores Dart ints as Long — match it so Dart getInt() works
        prefs(context).edit().putLong(KEY_PREFIX + key, value.toLong()).apply()
    }
}
