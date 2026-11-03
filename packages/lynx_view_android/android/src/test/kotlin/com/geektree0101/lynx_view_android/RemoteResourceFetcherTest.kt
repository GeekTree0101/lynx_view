package com.geektree0101.lynx_view_android

import com.lynx.tasm.resourceprovider.LynxResourceCallback
import com.lynx.tasm.resourceprovider.LynxResourceRequest
import com.lynx.tasm.resourceprovider.LynxResourceResponse
import java.io.File
import java.net.InetAddress
import java.net.ServerSocket
import java.util.concurrent.Executor
import kotlin.concurrent.thread
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Runs the fetcher against a loopback HTTP server. The executor is the
 * calling thread so every callback has fired by the time `fetch*` returns.
 *
 * The server is a `ServerSocket` loop rather than `com.sun.net.httpserver`:
 * Android unit tests compile against `android.jar`, which does not carry the
 * JDK's HTTP server, and a dependency for two routes is not worth having.
 */
internal class RemoteResourceFetcherTest {
    private lateinit var server: ServerSocket
    private val fetcher = RemoteResourceFetcher(executor = Executor { it.run() })
    private val svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"/>".toByteArray()

    private val baseUrl: String
        get() = "http://127.0.0.1:${server.localPort}"

    @BeforeTest
    fun startServer() {
        server = ServerSocket(0, 0, InetAddress.getLoopbackAddress())
        thread(isDaemon = true) {
            while (!server.isClosed) {
                val socket = try { server.accept() } catch (_: java.io.IOException) { return@thread }
                socket.use {
                    val requestLine = it.getInputStream().bufferedReader().readLine() ?: return@use
                    val path = requestLine.split(" ").getOrNull(1)
                    val response = if (path == "/icon.svg") {
                        "HTTP/1.1 200 OK\r\nContent-Type: image/svg+xml\r\nContent-Length: ${svg.size}\r\nConnection: close\r\n\r\n".toByteArray() + svg
                    } else {
                        "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".toByteArray()
                    }
                    it.getOutputStream().apply { write(response); flush() }
                }
            }
        }
    }

    @AfterTest
    fun stopServer() {
        server.close()
    }

    private fun <T> fetch(block: (LynxResourceCallback<T>) -> Unit): LynxResourceResponse<T> {
        var captured: LynxResourceResponse<T>? = null
        block(LynxResourceCallback { captured = it })
        return assertNotNull(captured, "callback never fired")
    }

    @Test
    fun `fetchResource returns the bytes of a 2xx response`() {
        val request = LynxResourceRequest("$baseUrl/icon.svg", LynxResourceRequest.LynxResourceType.LynxResourceTypeSVG)

        val response = fetch<ByteArray> { fetcher.fetchResource(request, it) }

        assertEquals(LynxResourceResponse.ResponseState.SUCCESS, response.state)
        assertContentEquals(svg, response.data)
    }

    @Test
    fun `fetchResource fails on a non-2xx status`() {
        val request = LynxResourceRequest("$baseUrl/missing.svg", LynxResourceRequest.LynxResourceType.LynxResourceTypeSVG)

        val response = fetch<ByteArray> { fetcher.fetchResource(request, it) }

        assertEquals(LynxResourceResponse.ResponseState.FAILED, response.state)
        assertTrue(response.error.message!!.contains("404"), response.error.message)
    }

    @Test
    fun `fetchResource fails on a scheme it does not serve`() {
        val request = LynxResourceRequest("file:///etc/hosts", LynxResourceRequest.LynxResourceType.LynxResourceTypeGeneric)

        val response = fetch<ByteArray> { fetcher.fetchResource(request, it) }

        assertEquals(LynxResourceResponse.ResponseState.FAILED, response.state)
        assertTrue(response.error.message!!.contains("file"), response.error.message)
    }

    @Test
    fun `fetchResource fails on an unparseable URL`() {
        val request = LynxResourceRequest("not a url", LynxResourceRequest.LynxResourceType.LynxResourceTypeGeneric)

        val response = fetch<ByteArray> { fetcher.fetchResource(request, it) }

        assertEquals(LynxResourceResponse.ResponseState.FAILED, response.state)
    }

    @Test
    fun `fetchResourcePath writes the bytes to a file and returns its path`() {
        val request = LynxResourceRequest("$baseUrl/icon.svg", LynxResourceRequest.LynxResourceType.LynxResourceTypeFont)

        val response = fetch<String> { fetcher.fetchResourcePath(request, it) }

        assertEquals(LynxResourceResponse.ResponseState.SUCCESS, response.state)
        val file = File(response.data)
        try {
            assertContentEquals(svg, file.readBytes())
        } finally {
            file.delete()
        }
    }
}
