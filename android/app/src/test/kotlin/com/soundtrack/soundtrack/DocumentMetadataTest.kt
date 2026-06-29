package com.soundtrack.soundtrack

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DocumentMetadataTest {
    @Test
    fun `document metadata maps values for the Flutter channel`() {
        val metadata =
            DocumentMetadata(
                uri = "content://audio/42",
                displayName = "entrance.mp3",
                mimeType = "audio/mpeg",
                size = 12345L,
            )

        assertEquals(
            mapOf(
                "uri" to "content://audio/42",
                "displayName" to "entrance.mp3",
                "mimeType" to "audio/mpeg",
                "size" to 12345L,
            ),
            metadata.toChannelMap(),
        )
    }

    @Test
    fun `document metadata preserves absent optional values`() {
        val metadata =
            DocumentMetadata(
                uri = "content://audio/42",
                displayName = "audio-42",
                mimeType = null,
                size = null,
            )

        assertNull(metadata.toChannelMap()["mimeType"])
        assertNull(metadata.toChannelMap()["size"])
    }

    @Test
    fun `audio probe parses duration and normalizes blank artist`() {
        val probe = AudioProbeMetadata.fromRaw(artist = "  ", durationMs = "90500")

        assertEquals(
            mapOf(
                "playable" to true,
                "artist" to null,
                "durationMs" to 90500L,
            ),
            probe.toChannelMap(),
        )
    }
}
