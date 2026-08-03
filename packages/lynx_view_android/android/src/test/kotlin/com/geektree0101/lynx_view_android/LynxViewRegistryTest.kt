package com.geektree0101.lynx_view_android

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertSame
import org.mockito.Mockito

internal class LynxViewRegistryTest {
    private val registeredIds = mutableListOf<Int>()

    private fun fakeChannel(): MethodChannel {
        val messenger = Mockito.mock(BinaryMessenger::class.java)
        return MethodChannel(messenger, "test")
    }

    @AfterTest
    fun cleanup() {
        registeredIds.forEach { LynxViewRegistry.unregister(it) }
        registeredIds.clear()
    }

    @Test
    fun `channelFor returns null when nothing registered for that viewId`() {
        assertNull(LynxViewRegistry.channelFor(999_001))
    }

    @Test
    fun `register then channelFor returns the same channel instance`() {
        val channel = fakeChannel()
        LynxViewRegistry.register(999_002, channel)
        registeredIds.add(999_002)

        assertSame(channel, LynxViewRegistry.channelFor(999_002))
    }

    @Test
    fun `unregister removes the mapping`() {
        val channel = fakeChannel()
        LynxViewRegistry.register(999_003, channel)
        registeredIds.add(999_003)

        LynxViewRegistry.unregister(999_003)
        registeredIds.remove(999_003)

        assertNull(LynxViewRegistry.channelFor(999_003))
    }

    @Test
    fun `registering a new channel for the same viewId replaces the old one`() {
        val first = fakeChannel()
        val second = fakeChannel()
        LynxViewRegistry.register(999_004, first)
        LynxViewRegistry.register(999_004, second)
        registeredIds.add(999_004)

        assertSame(second, LynxViewRegistry.channelFor(999_004))
    }
}
