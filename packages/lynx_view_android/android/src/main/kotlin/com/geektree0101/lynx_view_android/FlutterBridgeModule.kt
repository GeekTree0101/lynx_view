package com.geektree0101.lynx_view_android

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.lynx.jsbridge.LynxMethod
import com.lynx.jsbridge.LynxModule
import com.lynx.tasm.behavior.LynxContext

/**
 * Built-in, package-provided native module — the "Tier 1" generic JS <-> Dart
 * pipe described in the techspec (`addJavaScriptChannel`/`sendEvent` on
 * `LynxViewController`, no app-authored native code required). Always
 * registered automatically by [LynxViewPlugin.ensureInitialized]; apps only
 * need [LynxViewPlugin.registerNativeModule] for "Tier 2" custom modules.
 *
 * JS side: `NativeModules.FlutterBridge.postMessage(channel, payload)`.
 */
internal class FlutterBridgeModule(context: Context) : LynxModule(context) {
    private val mainHandler = Handler(Looper.getMainLooper())

    @LynxMethod
    fun postMessage(channel: String, payload: String) {
        // mContext is the LynxContext for the specific LynxView this module
        // instance is attached to (LynxModule is instantiated per-view even
        // though registration is global — see the techspec's Native Module
        // design note). LynxContext.getLynxView() is a confirmed real API
        // (verified against the lynx-4.0.0.aar bytecode).
        val viewId = ((mContext as? LynxContext)?.lynxView?.tag as? Int) ?: return
        val methodChannel = LynxViewRegistry.channelFor(viewId) ?: return
        mainHandler.post {
            methodChannel.invokeMethod(
                "onMessage",
                mapOf("channel" to channel, "payload" to payload),
            )
        }
    }

    companion object {
        const val NAME = "FlutterBridge"
    }
}
