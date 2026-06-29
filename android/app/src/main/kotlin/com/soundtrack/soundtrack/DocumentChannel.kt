package com.soundtrack.soundtrack

import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

data class DocumentMetadata(
    val uri: String,
    val displayName: String,
    val mimeType: String?,
    val size: Long?,
) {
    fun toChannelMap(): Map<String, Any?> =
        mapOf(
            "uri" to uri,
            "displayName" to displayName,
            "mimeType" to mimeType,
            "size" to size,
        )
}

data class AudioProbeMetadata(
    val playable: Boolean,
    val artist: String?,
    val durationMs: Long?,
) {
    fun toChannelMap(): Map<String, Any?> =
        mapOf(
            "playable" to playable,
            "artist" to artist,
            "durationMs" to durationMs,
        )

    companion object {
        fun fromRaw(
            artist: String?,
            durationMs: String?,
        ): AudioProbeMetadata =
            AudioProbeMetadata(
                playable = true,
                artist = artist?.trim()?.takeIf { it.isNotEmpty() },
                durationMs = durationMs?.toLongOrNull(),
            )

        fun unplayable(): AudioProbeMetadata =
            AudioProbeMetadata(playable = false, artist = null, durationMs = null)
    }
}

class DocumentChannel(
    private val activity: FlutterFragmentActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val resolver: ContentResolver = activity.contentResolver
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val ioRunner =
        DocumentIoRunner(
            executor = Executors.newSingleThreadExecutor(),
            postToMain = { action -> activity.runOnUiThread(Runnable(action)) },
        )
    private var pending: PendingOperation? = null
    private var disposed = false

    private val audioPicker =
        activity.registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
            val operation = pendingAs<PendingOperation.PickAudio>() ?: return@registerForActivityResult
            if (uri == null) {
                completePending(operation, null)
                return@registerForActivityResult
            }
            runPendingIo(operation, "pick_failed") {
                resolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
                readDocumentMetadata(uri).toChannelMap()
            }
        }

    private val eventPicker =
        activity.registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
            val operation = pendingAs<PendingOperation.OpenEvent>() ?: return@registerForActivityResult
            if (uri == null) {
                completePending(operation, null)
                return@registerForActivityResult
            }
            runPendingIo(operation, "read_failed") {
                val declaredSize = querySize(uri)
                resolver.openInputStream(uri)?.use {
                    BoundedUtf8Reader.read(it, declaredSize)
                } ?: throw IllegalStateException("Unable to open selected document")
            }
        }

    private val eventCreator =
        activity.registerForActivityResult(ActivityResultContracts.CreateDocument(JSON_MIME)) { uri ->
            val operation = pendingAs<PendingOperation.CreateEvent>() ?: return@registerForActivityResult
            if (uri == null) {
                completePending(operation, false)
                return@registerForActivityResult
            }
            runPendingIo(operation, "write_failed") {
                resolver.openOutputStream(uri)?.bufferedWriter(Charsets.UTF_8)?.use {
                    it.write(operation.contents)
                } ?: throw IllegalStateException("Unable to create selected document")
                true
            }
        }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "pickAudio" ->
                launchPicker(result, PendingOperation.PickAudio(result)) {
                    audioPicker.launch(arrayOf("audio/*"))
                }
            "openEventJson" ->
                launchPicker(result, PendingOperation.OpenEvent(result)) {
                    eventPicker.launch(JSON_TYPES)
                }
            "createEventJson" -> createEvent(call, result)
            "canRead" -> runDetachedIo(result) { canRead(requireUri(call)) }
            "probeAudio" ->
                runDetachedIo(result) {
                    probeAudio(requireUri(call)).toChannelMap()
                }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        if (disposed) {
            return
        }
        disposed = true
        channel.setMethodCallHandler(null)
        when (val operation = pending.also { pending = null }) {
            is PendingOperation.CreateEvent -> operation.result.success(false)
            is PendingOperation.OpenEvent,
            is PendingOperation.PickAudio,
            -> operation.result.success(null)
            null -> Unit
        }
        ioRunner.close()
    }

    private fun createEvent(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val suggestedName = call.argument<String>("suggestedName")
        val contents = call.argument<String>("contents")
        if (suggestedName == null || contents == null) {
            result.error("bad_args", "suggestedName and contents are required", null)
            return
        }
        launchPicker(result, PendingOperation.CreateEvent(result, contents)) {
            eventCreator.launch(suggestedName)
        }
    }

    private fun launchPicker(
        result: MethodChannel.Result,
        operation: PendingOperation,
        launch: () -> Unit,
    ) {
        if (pending != null) {
            result.error("picker_busy", "Another document picker is already active", null)
            return
        }
        pending = operation
        try {
            launch()
        } catch (error: Exception) {
            if (pending === operation) {
                pending = null
                result.error("picker_failed", error.message, null)
            }
        }
    }

    private fun <T> runPendingIo(
        operation: PendingOperation,
        errorCode: String,
        task: () -> T,
    ) {
        ioRunner.run(task) { outcome ->
            if (pending !== operation || disposed) {
                return@run
            }
            outcome.fold(
                onSuccess = { completePending(operation, it) },
                onFailure = { error ->
                    pending = null
                    operation.result.error(
                        documentIoErrorCode(error, errorCode),
                        error.message,
                        null,
                    )
                },
            )
        }
    }

    private fun <T> runDetachedIo(
        result: MethodChannel.Result,
        task: () -> T,
    ) {
        ioRunner.run(task) { outcome ->
            if (disposed) {
                return@run
            }
            outcome.fold(
                onSuccess = result::success,
                onFailure = { error ->
                    result.error("document_io_failed", error.message, null)
                },
            )
        }
    }

    private fun completePending(
        operation: PendingOperation,
        value: Any?,
    ) {
        if (pending !== operation || disposed) {
            return
        }
        pending = null
        operation.result.success(value)
    }

    private inline fun <reified T : PendingOperation> pendingAs(): T? {
        return pending as? T
    }

    private fun requireUri(call: MethodCall): Uri {
        val value =
            call.argument<String>("uri")
                ?: throw IllegalArgumentException("uri is required")
        return Uri.parse(value)
    }

    private fun readDocumentMetadata(uri: Uri): DocumentMetadata {
        var displayName: String? = null
        var size: Long? = null
        resolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                displayName = cursor.stringOrNull(OpenableColumns.DISPLAY_NAME)
                size = cursor.longOrNull(OpenableColumns.SIZE)
            }
        }
        return DocumentMetadata(
            uri = uri.toString(),
            displayName = displayName ?: uri.lastPathSegment ?: "document",
            mimeType = resolver.getType(uri),
            size = size,
        )
    }

    private fun querySize(uri: Uri): Long? {
        resolver.query(
            uri,
            arrayOf(OpenableColumns.SIZE),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.longOrNull(OpenableColumns.SIZE)?.takeIf { it >= 0 }
            }
        }
        return null
    }

    private fun canRead(uri: Uri): Boolean {
        try {
            resolver.openAssetFileDescriptor(uri, "r")?.use { return true }
        } catch (_: Exception) {
            // Some providers only expose streams.
        }
        return try {
            resolver.openInputStream(uri)?.use { true } ?: false
        } catch (_: Exception) {
            false
        }
    }

    private fun probeAudio(uri: Uri): AudioProbeMetadata {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(activity, uri)
            AudioProbeMetadata.fromRaw(
                artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST),
                durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION),
            )
        } catch (_: Exception) {
            AudioProbeMetadata.unplayable()
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
                // Nothing else to release.
            }
        }
    }

    private sealed interface PendingOperation {
        val result: MethodChannel.Result

        data class PickAudio(override val result: MethodChannel.Result) : PendingOperation

        data class OpenEvent(override val result: MethodChannel.Result) : PendingOperation

        data class CreateEvent(
            override val result: MethodChannel.Result,
            val contents: String,
        ) : PendingOperation
    }

    companion object {
        private const val CHANNEL_NAME = "com.soundtrack/documents"
        private const val JSON_MIME = "application/json"
        private val JSON_TYPES =
            arrayOf(
                JSON_MIME,
                "text/plain",
                "application/octet-stream",
            )
    }
}

private fun Cursor.stringOrNull(columnName: String): String? {
    val index = getColumnIndex(columnName)
    return if (index >= 0 && !isNull(index)) getString(index) else null
}

private fun Cursor.longOrNull(columnName: String): Long? {
    val index = getColumnIndex(columnName)
    return if (index >= 0 && !isNull(index)) getLong(index) else null
}
