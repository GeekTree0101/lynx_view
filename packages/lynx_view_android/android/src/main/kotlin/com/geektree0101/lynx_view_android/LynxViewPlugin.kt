package com.geektree0101.lynx_view_android

import android.app.Application
import android.content.Context
import com.lynx.jsbridge.LynxModule
import com.lynx.tasm.LynxEnv

/**
 * Public entry point for apps that need a custom native module reachable
 * from Lynx JS (`NativeModules.YourCustomModule`). Call
 * [registerNativeModule] once at app startup (e.g. `Application.onCreate`).
 *
 * Lynx only supports registering modules globally against `LynxEnv`, not per
 * `LynxView` instance — see the design note in the techspec. Since `LynxEnv`
 * is only actually initialized lazily, the first time a `LynxView` is
 * created (see [ensureInitialized]), calls made here are safe regardless of
 * whether that has happened yet: they're queued and flushed at that point.
 */
object LynxViewPlugin {
    private val pendingModules =
        mutableListOf<Pair<String, Class<out LynxModule>>>()
    private var initialized = false

    @JvmStatic
    fun registerNativeModule(name: String, moduleClass: Class<out LynxModule>) {
        synchronized(this) {
            if (initialized) {
                LynxEnv.inst().registerModule(name, moduleClass)
            } else {
                pendingModules.add(name to moduleClass)
            }
        }
    }

    @JvmStatic
    fun unregisterNativeModule(name: String) {
        synchronized(this) {
            pendingModules.removeAll { it.first == name }
            // TODO(Phase 3 SDK verification): confirm LynxEnv exposes an
            // unregister call for modules registered after init; Lynx's
            // public docs only show registration, not removal.
        }
    }

    /**
     * Lazily performs the real `LynxEnv.inst().init()` call the first time
     * it's needed (i.e. right before the first native `LynxView` is
     * created), then flushes any module registrations queued via
     * [registerNativeModule] up to this point. Safe to call repeatedly.
     */
    @JvmStatic
    fun ensureInitialized(context: Context) {
        synchronized(this) {
            if (initialized) return
            LynxEnv.inst().init(
                context.applicationContext as Application,
                /* nativeLibraryLoader = */ null,
                /* templateProvider = */ RemoteTemplateProvider(),
                /* behaviorBundle = */ null,
            )
            LynxEnv.inst().registerModule(FlutterBridgeModule.NAME, FlutterBridgeModule::class.java)
            pendingModules.forEach { (name, moduleClass) ->
                LynxEnv.inst().registerModule(name, moduleClass)
            }
            pendingModules.clear()
            initialized = true
        }
    }

    /** Test-only: names still queued (i.e. not yet flushed by [ensureInitialized]). */
    internal fun pendingModuleNamesForTesting(): List<String> =
        synchronized(this) { pendingModules.map { it.first } }

    /** Test-only: resets singleton state between test cases. Never call from app code. */
    internal fun resetForTesting() {
        synchronized(this) {
            pendingModules.clear()
            initialized = false
        }
    }
}
