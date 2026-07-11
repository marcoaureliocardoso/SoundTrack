package br.com.marcocardoso.soundtrack

import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.util.concurrent.Executor
import java.util.concurrent.ExecutorService

/** Maximum accepted event document size: 5 MiB of UTF-8 encoded data. */
const val MAX_EVENT_JSON_BYTES: Int = 5 * 1024 * 1024

class DocumentTooLargeException :
    Exception("Document exceeds the $MAX_EVENT_JSON_BYTES byte limit")

fun documentIoErrorCode(
    error: Throwable,
    fallback: String,
): String = if (error is DocumentTooLargeException) "document_too_large" else fallback

object BoundedUtf8Reader {
    fun read(
        input: InputStream,
        declaredSize: Long?,
        maxBytes: Int = MAX_EVENT_JSON_BYTES,
    ): String {
        if (declaredSize != null && declaredSize > maxBytes) {
            throw DocumentTooLargeException()
        }

        val initialCapacity =
            declaredSize
                ?.coerceAtLeast(0)
                ?.coerceAtMost(maxBytes.toLong())
                ?.toInt()
                ?: DEFAULT_BUFFER_SIZE
        val output = ByteArrayOutputStream(initialCapacity)
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var total = 0
        while (true) {
            val count = input.read(buffer)
            if (count < 0) {
                break
            }
            if (total > maxBytes - count) {
                throw DocumentTooLargeException()
            }
            output.write(buffer, 0, count)
            total += count
        }
        return output.toString(Charsets.UTF_8.name())
    }
}

class DocumentIoRunner(
    private val executor: Executor,
    private val postToMain: (() -> Unit) -> Unit,
) {
    fun <T> run(
        task: () -> T,
        complete: (Result<T>) -> Unit,
    ) {
        try {
            executor.execute {
                val outcome = runCatching(task)
                postToMain { complete(outcome) }
            }
        } catch (error: Exception) {
            postToMain { complete(Result.failure(error)) }
        }
    }

    fun close() {
        (executor as? ExecutorService)?.shutdownNow()
    }
}
