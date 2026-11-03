package com.geektree0101.lynx_view_android

import com.lynx.tasm.resourceprovider.LynxResourceCallback
import com.lynx.tasm.resourceprovider.LynxResourceRequest
import com.lynx.tasm.resourceprovider.LynxResourceResponse
import com.lynx.tasm.resourceprovider.generic.LynxGenericResourceFetcher
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * The generic resource fetcher Lynx asks for anything that is not an
 * `<image>`: an `<svg src="https://…">`, a font named by URL, a Lottie file.
 *
 * Lynx has no built-in loader for these. `<image>` goes through the image
 * service (Fresco here), but the rest go through
 * `LynxContext.getGenericResourceFetcher()`, and when that is null XElement's
 * `<svg>` logs `getGenericResourceFetcher is null, svg fetch src failed!` and
 * draws nothing. This is the default; a host that needs auth headers or its
 * own cache swaps it with [LynxViewPlugin.setResourceFetcher].
 *
 * Plain `GET` over HTTP(S), no headers added, default cache behaviour. The
 * template provider forces revalidation because OTA republishes at one URL;
 * resources are addressed by content (a new icon is a new key) and need no
 * such care.
 */
internal class RemoteResourceFetcher(
    private val executor: java.util.concurrent.Executor = sharedExecutor,
) : LynxGenericResourceFetcher() {

    override fun fetchResource(
        request: LynxResourceRequest,
        callback: LynxResourceCallback<ByteArray>,
    ) {
        executor.execute {
            try {
                callback.onResponse(LynxResourceResponse.onSuccess(download(request.url)))
            } catch (e: IOException) {
                callback.onResponse(failed(e))
            }
        }
    }

    /**
     * Same bytes, parked in a temp file. Lynx asks for a path rather than
     * bytes for the few resources it hands to a platform API that wants a
     * file. The file is never removed; the OS owns the temp directory.
     */
    override fun fetchResourcePath(
        request: LynxResourceRequest,
        callback: LynxResourceCallback<String>,
    ) {
        executor.execute {
            try {
                val file = File.createTempFile("lynx_resource_", null)
                file.writeBytes(download(request.url))
                callback.onResponse(LynxResourceResponse.onSuccess(file.absolutePath))
            } catch (e: IOException) {
                callback.onResponse(failed(e))
            }
        }
    }

    @Throws(IOException::class)
    internal fun download(url: String): ByteArray {
        val parsed = try {
            URL(url)
        } catch (e: java.net.MalformedURLException) {
            throw IOException("Invalid resource URL: $url", e)
        }
        if (parsed.protocol != "http" && parsed.protocol != "https") {
            throw IOException("Unsupported resource URL scheme '${parsed.protocol}': $url")
        }
        val connection = parsed.openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 15_000
        connection.readTimeout = 15_000
        try {
            if (connection.responseCode !in 200..299) {
                throw IOException("HTTP ${connection.responseCode} for $url")
            }
            connection.inputStream.use { input ->
                ByteArrayOutputStream().use { output ->
                    val buffer = ByteArray(8 * 1024)
                    var read: Int
                    while (input.read(buffer).also { read = it } != -1) {
                        output.write(buffer, 0, read)
                    }
                    return output.toByteArray()
                }
            }
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        private val sharedExecutor by lazy { Executors.newCachedThreadPool() }

        /** `onFailed` is declared raw on the Lynx side; this gives it the type the callback wants. */
        @Suppress("UNCHECKED_CAST")
        private fun <T> failed(error: Throwable): LynxResourceResponse<T> =
            LynxResourceResponse.onFailed(error) as LynxResourceResponse<T>
    }
}
