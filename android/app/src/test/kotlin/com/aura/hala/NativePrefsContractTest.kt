package com.aura.hala

import org.junit.Assert.fail
import org.junit.Test
import java.io.File

class NativePrefsContractTest {
    private val sourceDir = File("src/main/kotlin/com/aura/hala")

    private fun kotlinFiles(): List<File> =
        sourceDir.listFiles()?.filter { it.extension == "kt" } ?: emptyList()

    private fun isComment(line: String): Boolean {
        val t = line.trimStart()
        return t.startsWith("//") || t.startsWith("*") || t.startsWith("/*")
    }

    @Test
    fun `no file references aura_prefs`() {
        val violations = mutableListOf<String>()
        for (file in kotlinFiles()) {
            file.readLines().forEachIndexed { i, line ->
                if (!isComment(line) && line.contains("\"aura_prefs\"")) {
                    violations.add("${file.name}:${i + 1}: ${line.trim()}")
                }
            }
        }
        if (violations.isNotEmpty()) {
            fail("Files must not read aura_prefs (use FlutterPrefs):\n${violations.joinToString("\n")}")
        }
    }

    @Test
    fun `settings keys use FlutterPrefs`() {
        val keys = listOf("silent_mode_enabled", "adhan_enabled", "background_notification_enabled", "selected_adhan_id")
        val violations = mutableListOf<String>()
        for (file in kotlinFiles()) {
            file.readLines().forEachIndexed { i, line ->
                if (isComment(line)) return@forEachIndexed
                for (key in keys) {
                    if (line.contains("\"$key\"") && !line.contains("FlutterPrefs.")) {
                        violations.add("${file.name}:${i + 1}: $key without FlutterPrefs: ${line.trim()}")
                    }
                }
            }
        }
        if (violations.isNotEmpty()) {
            fail("Settings keys must be read through FlutterPrefs:\n${violations.joinToString("\n")}")
        }
    }

    @Test
    fun `startService callers are on allowlist`() {
        val allowlist = setOf("PrayerForegroundService.kt", "MainActivity.kt", "BackgroundServiceHandler.kt")
        val violations = mutableListOf<String>()
        for (file in kotlinFiles()) {
            if (file.name in allowlist) continue
            file.readLines().forEachIndexed { i, line ->
                if (!isComment(line) && line.contains("PrayerForegroundService.startService(")) {
                    violations.add("${file.name}:${i + 1}: ${line.trim()}")
                }
            }
        }
        if (violations.isNotEmpty()) {
            fail("Only allowlisted files may call PrayerForegroundService.startService:\n${violations.joinToString("\n")}")
        }
    }
}
