package com.geektree0101.lynx_view_android

import android.content.Context
import io.flutter.plugin.common.MethodChannel
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import org.mockito.Mockito

/**
 * Guards the routing that was dead on Android for every release up to 1.7.0:
 * the module resolved its Flutter view through `LynxContext.getLynxView()`
 * and `LynxView.getTag()`, neither of which answers on Android, and dropped
 * every message without a word. Nothing here needs a live `LynxView` — which
 * is the point, and only became possible once the viewId came in as a param.
 */
internal class FlutterBridgeModuleTest {
    private val registeredIds = mutableListOf<Int>()

    @AfterTest
    fun cleanup() {
        registeredIds.forEach { LynxViewRegistry.unregister(it) }
        registeredIds.clear()
    }

    private fun moduleFor(param: Any): Pair<FlutterBridgeModule, MutableList<String>> {
        val module = FlutterBridgeModule(Mockito.mock(Context::class.java), param)
        val reported = mutableListOf<String>()
        module.report = { reported.add(it) }
        // The real one hops to the main looper, which a JVM test does not have.
        module.dispatchToMain = { block -> block() }
        return module to reported
    }

    private fun registerChannel(viewId: Int): MethodChannel {
        val channel = Mockito.mock(MethodChannel::class.java)
        LynxViewRegistry.register(viewId, channel)
        registeredIds.add(viewId)
        return channel
    }

    @Test
    fun `postMessage reaches the channel registered for its viewId`() {
        val channel = registerChannel(998_001)
        val (module, reported) = moduleFor(998_001)

        module.postMessage("bridge", """{"id":"1","method":"prefs.read"}""")

        Mockito.verify(channel).invokeMethod(
            "onMessage",
            mapOf(
                "channel" to "bridge",
                "payload" to """{"id":"1","method":"prefs.read"}""",
            ),
        )
        assertTrue(reported.isEmpty())
    }

    @Test
    fun `two views do not cross — each message goes to its own channel`() {
        val first = registerChannel(998_002)
        val second = registerChannel(998_003)
        val (moduleForFirst, _) = moduleFor(998_002)

        moduleForFirst.postMessage("bridge", "hello")

        Mockito.verify(first).invokeMethod(
            "onMessage",
            mapOf("channel" to "bridge", "payload" to "hello"),
        )
        Mockito.verifyNoInteractions(second)
    }

    @Test
    fun `a module built without a viewId reports instead of swallowing`() {
        val (module, reported) = moduleFor("not-a-view-id")

        module.postMessage("bridge", "hello")

        assertEquals(1, reported.size)
        assertTrue(reported.single().contains("no Flutter viewId"))
    }

    @Test
    fun `a message for a disposed view reports instead of swallowing`() {
        val (module, reported) = moduleFor(998_004)

        module.postMessage("bridge", "hello")

        assertEquals(1, reported.size)
        assertTrue(reported.single().contains("already gone"))
    }
}
