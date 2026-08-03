package com.geektree0101.lynx_view_android

import com.lynx.tasm.provider.AbsTemplateProvider
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Fetches a Lynx template bundle from a remote HTTP(S) URL — this package's
 * v1 loading strategy is "remote only" per the techspec (no bundled asset
 * loading, no on-disk caching between loads).
 *
 * No custom-header support yet (v1 signature has none — see the techspec's
 * still-open S3-access-method question); revisit if/when that's decided.
 */
internal class RemoteTemplateProvider : AbsTemplateProvider() {
    private val executor = Executors.newCachedThreadPool()

    override fun loadTemplate(uri: String, callback: Callback) {
        executor.execute {
            try {
                val connection = URL(uri).openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 15_000
                connection.readTimeout = 15_000
                try {
                    if (connection.responseCode !in 200..299) {
                        callback.onFailed("HTTP ${connection.responseCode} for $uri")
                        return@execute
                    }
                    connection.inputStream.use { input ->
                        ByteArrayOutputStream().use { output ->
                            val buffer = ByteArray(8 * 1024)
                            var read: Int
                            while (input.read(buffer).also { read = it } != -1) {
                                output.write(buffer, 0, read)
                            }
                            callback.onSuccess(output.toByteArray())
                        }
                    }
                } finally {
                    connection.disconnect()
                }
            } catch (e: IOException) {
                callback.onFailed(e.message ?: "Failed to load template from $uri")
            }
        }
    }
}
