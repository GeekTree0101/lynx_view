package com.geektree0101.lynx_view_android

import android.content.Context
import com.lynx.jsbridge.LynxModule
import com.lynx.tasm.resourceprovider.LynxResourceCallback
import com.lynx.tasm.resourceprovider.LynxResourceRequest
import com.lynx.tasm.resourceprovider.generic.LynxGenericResourceFetcher
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertSame

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

    @Test
    fun `resourceFetcher is the plain HTTP one until a host sets its own`() {
        assertIs<RemoteResourceFetcher>(LynxViewPlugin.resourceFetcher())
    }

    @Test
    fun `setResourceFetcher replaces the default and null restores it`() {
        val custom = object : LynxGenericResourceFetcher() {
            override fun fetchResource(request: LynxResourceRequest, callback: LynxResourceCallback<ByteArray>) = Unit
            override fun fetchResourcePath(request: LynxResourceRequest, callback: LynxResourceCallback<String>) = Unit
        }

        LynxViewPlugin.setResourceFetcher(custom)
        assertSame(custom, LynxViewPlugin.resourceFetcher())

        LynxViewPlugin.setResourceFetcher(null)
        assertIs<RemoteResourceFetcher>(LynxViewPlugin.resourceFetcher())
    }
}
