package com.soundtrack.soundtrack

import java.io.ByteArrayInputStream
import java.util.ArrayDeque
import java.util.concurrent.Executor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class DocumentIoTest {
    @Test
    fun `bounded reader accepts exactly the byte limit`() {
        val bytes = "12345".toByteArray(Charsets.UTF_8)

        val contents =
            BoundedUtf8Reader.read(
                input = ByteArrayInputStream(bytes),
                declaredSize = bytes.size.toLong(),
                maxBytes = bytes.size,
            )

        assertEquals("12345", contents)
    }

    @Test
    fun `bounded reader rejects declared size above the limit`() {
        assertThrows(DocumentTooLargeException::class.java) {
            BoundedUtf8Reader.read(
                input = ByteArrayInputStream(byteArrayOf()),
                declaredSize = 6,
                maxBytes = 5,
            )
        }
    }

    @Test
    fun `bounded reader stops streaming above the limit when size is unknown`() {
        assertThrows(DocumentTooLargeException::class.java) {
            BoundedUtf8Reader.read(
                input = ByteArrayInputStream("123456".toByteArray(Charsets.UTF_8)),
                declaredSize = null,
                maxBytes = 5,
            )
        }
    }

    @Test
    fun `bounded reader counts UTF-8 bytes and decodes contents`() {
        val contents = "áudio 🎵"
        val bytes = contents.toByteArray(Charsets.UTF_8)

        val decoded =
            BoundedUtf8Reader.read(
                input = ByteArrayInputStream(bytes),
                declaredSize = null,
                maxBytes = bytes.size,
            )

        assertEquals(contents, decoded)
    }

    @Test
    fun `oversized document maps to the dedicated channel error`() {
        assertEquals(
            "document_too_large",
            documentIoErrorCode(DocumentTooLargeException(), "read_failed"),
        )
        assertEquals(
            "read_failed",
            documentIoErrorCode(IllegalStateException("broken"), "read_failed"),
        )
    }

    @Test
    fun `IO runner separates worker execution from main completion`() {
        val ioTasks = ArrayDeque<Runnable>()
        val mainTasks = ArrayDeque<Runnable>()
        val runner =
            DocumentIoRunner(
                executor = Executor { ioTasks.add(it) },
                postToMain = { mainTasks.add(Runnable(it)) },
            )
        var ioRan = false
        var completed = false

        runner.run(
            task = {
                ioRan = true
                42
            },
            complete = {
                assertEquals(42, it.getOrThrow())
                completed = true
            },
        )

        assertFalse(ioRan)
        assertFalse(completed)
        ioTasks.removeFirst().run()
        assertTrue(ioRan)
        assertFalse(completed)
        mainTasks.removeFirst().run()
        assertTrue(completed)
    }
}
