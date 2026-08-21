package com.geektree0101.lynx_view_android

import android.app.Application
import android.content.Context
import com.facebook.drawee.backends.pipeline.Fresco
import com.facebook.imagepipeline.core.ImagePipelineConfig
import com.facebook.imagepipeline.memory.PoolConfig
import com.facebook.imagepipeline.memory.PoolFactory
import com.lynx.jsbridge.LynxModule
import com.lynx.service.image.LynxImageService
import com.lynx.tasm.LynxEnv
import com.lynx.tasm.service.LynxServiceCenter

/**
 * Public entry point for apps that need a custom native module reachable
 * from Lynx JS (`NativeModules.YourCustomModule`). Call
 * [registerNativeModule] once at app startup (e.g. `Application.onCreate`).
 *
 * Modules registered here go on `LynxEnv`, so every `LynxView` in the
 * process sees them — which is what an app-authored module wants, since it
 * has no Flutter view to belong to. (Lynx does also allow per-view
 * registration through `LynxViewBuilder`; the package's own
 * [FlutterBridgeModule] needs that and uses it, but an app module would gain
 * nothing from it.) Since `LynxEnv` is only actually initialized lazily, the
 * first time a `LynxView` is created (see [ensureInitialized]), calls made
 * here are safe regardless of whether that has happened yet: they're queued
 * and flushed at that point.
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
            val appContext = context.applicationContext

            // Image service, registered before LynxEnv.init the way the
            // official integration guide orders it. Without this, <image>
            // silently renders nothing — Lynx delegates all fetch/decode to
            // the service and logs nothing when there is none.
            //
            // Fresco may already be initialized by the host app (it is public
            // API of a library the host can use directly); initializing twice
            // resets its caches, so guard it.
            if (!Fresco.hasBeenInitialized()) {
                val poolFactory = PoolFactory(PoolConfig.newBuilder().build())
                Fresco.initialize(
                    appContext,
                    ImagePipelineConfig.newBuilder(appContext)
                        .setPoolFactory(poolFactory)
                        .build(),
                )
            }
            LynxServiceCenter.inst().registerService(LynxImageService.getInstance())

            LynxEnv.inst().init(
                appContext as Application,
                /* nativeLibraryLoader = */ null,
                /* templateProvider = */ RemoteTemplateProvider(),
                /* behaviorBundle = */ null,
            )
            // FlutterBridgeModule is deliberately *not* registered here: it
            // needs to know which Flutter view it serves, and only a per-view
            // registration can tell it. LynxPlatformView does that on the
            // builder — see [FlutterBridgeModule].
            pendingModules.forEach { (name, moduleClass) ->
                LynxEnv.inst().registerModule(name, moduleClass)
            }
            pendingModules.clear()
            initialized = true
        }
    }

    /**
     * Whether the real `LynxEnv` has been created yet. Callers that only want
     * to talk to an existing env (rather than bring one into being) check this
     * first — see the memory-pressure handler in `LynxViewAndroidPlugin`.
     */
    @JvmStatic
    fun isInitialized(): Boolean = synchronized(this) { initialized }

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
