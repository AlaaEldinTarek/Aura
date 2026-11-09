package com.aura.hala

import android.content.Context
import io.flutter.util.PathUtils
import java.io.File

object AdhanFiles {
    private val ID_PATTERN = Regex("^[a-z0-9_]+$")

    fun resolve(selectedId: String, adhansDir: File): File? {
        if (!ID_PATTERN.matches(selectedId)) return null
        val file = File(adhansDir, "adhan_${selectedId}.mp3")
        return if (file.exists() && file.isFile) file else null
    }

    fun adhansDir(context: Context): File =
        File(PathUtils.getDataDirectory(context), "adhans")
}
