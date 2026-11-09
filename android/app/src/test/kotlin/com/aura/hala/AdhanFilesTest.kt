package com.aura.hala

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class AdhanFilesTest {
    @get:Rule
    val tmp = TemporaryFolder()

    @Test
    fun `empty id returns null`() {
        assertNull(AdhanFiles.resolve("", tmp.root))
    }

    @Test
    fun `path traversal id returns null`() {
        tmp.newFile("adhan_x.mp3")
        assertNull(AdhanFiles.resolve("../x", tmp.root))
    }

    @Test
    fun `uppercase id returns null`() {
        tmp.newFile("adhan_Alafasy.mp3")
        assertNull(AdhanFiles.resolve("Alafasy", tmp.root))
    }

    @Test
    fun `unknown id with no file returns null`() {
        assertNull(AdhanFiles.resolve("unknown", tmp.root))
    }

    @Test
    fun `existing file resolves`() {
        val file = tmp.newFile("adhan_alafasy.mp3")
        val result = AdhanFiles.resolve("alafasy", tmp.root)
        assertEquals(file, result)
    }

    @Test
    fun `zero byte file resolves`() {
        val file = tmp.newFile("adhan_sudais.mp3")
        assertEquals(0L, file.length())
        assertNotNull(AdhanFiles.resolve("sudais", tmp.root))
    }

    @Test
    fun `directory named like a file returns null`() {
        File(tmp.root, "adhan_x.mp3").mkdir()
        assertNull(AdhanFiles.resolve("x", tmp.root))
    }
}
