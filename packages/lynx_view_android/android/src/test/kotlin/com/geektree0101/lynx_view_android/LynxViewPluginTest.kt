package com.geektree0101.lynx_view_android

import android.content.Context
import com.lynx.jsbridge.LynxModule
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Covers the pre-init pending-module queue only — never calls
 * [LynxViewPlugin.ensureInitialized], which requires the real Lynx native
 * engine (only available on-device/emulator, not in a plain JVM unit test).
 */
private class DummyModule(context: Context) : LynxModule(context)

private class OtherDummyModule(context: Context) : LynxModule(context)

internal class LynxViewPluginTest {

    @BeforeTest
    fun resetSingletonState() {
        LynxViewPlugin.resetForTesting()
    }

    @AfterTest
    fun cleanupSingletonState() {
        LynxViewPlugin.resetForTesting()
    }

    @Test
    fun `registerNativeModule queues before ensureInitialized`() {
        LynxViewPlugin.registerNativeModule("Dummy", DummyModule::class.java)

        assertEquals(listOf("Dummy"), LynxViewPlugin.pendingModuleNamesForTesting())
    }

    @Test
    fun `multiple registrations queue in call order`() {
        LynxViewPlugin.registerNativeModule("A", DummyModule::class.java)
        LynxViewPlugin.registerNativeModule("B", OtherDummyModule::class.java)

        assertEquals(listOf("A", "B"), LynxViewPlugin.pendingModuleNamesForTesting())
    }

    @Test
    fun `unregisterNativeModule removes a pending registration`() {
        LynxViewPlugin.registerNativeModule("Dummy", DummyModule::class.java)
        LynxViewPlugin.registerNativeModule("Other", OtherDummyModule::class.java)

        LynxViewPlugin.unregisterNativeModule("Dummy")

        assertEquals(listOf("Other"), LynxViewPlugin.pendingModuleNamesForTesting())
    }

    @Test
    fun `unregisterNativeModule for an unknown name is a no-op`() {
        LynxViewPlugin.registerNativeModule("Dummy", DummyModule::class.java)

        LynxViewPlugin.unregisterNativeModule("DoesNotExist")

        assertEquals(listOf("Dummy"), LynxViewPlugin.pendingModuleNamesForTesting())
    }
}
