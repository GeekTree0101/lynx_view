package com.geektree0101.lynx_view_android

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.lynx.jsbridge.LynxMethod
import com.lynx.jsbridge.LynxModule
import com.lynx.tasm.base.LLog
import io.flutter.plugin.common.MethodChannel

/**
 * Built-in, package-provided native module — the "Tier 1" generic JS <-> Dart
 * pipe described in the techspec (`addJavaScriptChannel`/`sendEvent` on
 * `LynxViewController`, no app-authored native code required). Registered by
 * [LynxPlatformView] against the view it belongs to; apps only need
 * [LynxViewPlugin.registerNativeModule] for "Tier 2" custom modules.
 *
 * JS side: `NativeModules.FlutterBridge.postMessage(channel, payload)`.
 *
 * ## Why the Flutter viewId arrives as a constructor param
 *
 * A module instance has to find its way back to the one Flutter view it
 * belongs to. Reading that off the view — ask the `LynxContext` for its
 * `LynxView`, then read the tag the platform view stored on it — is the
 * obvious route and it cannot work on Android. Two independent reasons, both
 * verified against the lynx-4.0.0 AARs:
 *
 *  1. `LynxContext.setLynxView()` has no call site anywhere in the SDK —
 *     not in the Java classes, not as a JNI name inside `liblynx.so`. So
 *     `getLynxView()` always answers null.
 *  2. `LynxView` overrides `getTag()` to return the constant `"lynxview"`.
 *     Whatever `setTag` stored can never be read back.
 *
 * Both failed silently, so every JS->Dart message on Android was dropped
 * without a log while iOS — a plain `UIView`, whose `tag` really is an
 * integer — worked from the same code. The id is therefore handed to the
 * module when it is built, through Lynx's per-view registration
 * (`LynxViewBuilder.registerModule(name, class, param)`), which
 * `CommonModuleCreator` resolves ahead of anything registered globally on
 * `LynxEnv`.
 */
internal class FlutterBridgeModule(
    context: Context,
    param: Any,
) : LynxModule(context, param) {

    private val mainHandler: Handler by lazy { Handler(Looper.getMainLooper()) }

    /**
     * How work reaches the platform thread. Replaced only by tests: a plain
     * JVM unit test has no main `Looper`, and everything this class actually
     * decides happens *before* the hop.
     */
    internal var dispatchToMain: (() -> Unit) -> Unit = { block -> mainHandler.post { block() } }

    /**
     * Where a dropped message is reported. Injected for the same reason the
     * Dart side injects its reporter — the failure paths are the important
     * part of this class, and a static logger cannot be observed from a test.
     */
    internal var report: (String) -> Unit = { message -> LLog.e(TAG, message) }

    @LynxMethod
    fun postMessage(channel: String, payload: String) {
        val viewId = mParam as? Int
        if (viewId == null) {
            // Only reachable if this module was registered without its param
            // — globally on LynxEnv rather than per view. Nothing can be
            // routed; saying so is the whole point, since staying quiet here
            // is what hid a dead bridge for an entire release line.
            report("FlutterBridge: dropped a '$channel' message — this module has no Flutter viewId")
            return
        }
        val methodChannel = LynxViewRegistry.channelFor(viewId)
        if (methodChannel == null) {
            // Expected during teardown: the view was disposed while the
            // bundle still had a call in flight.
            report("FlutterBridge: dropped a '$channel' message — view $viewId is already gone")
            return
        }
        dispatchToMain {
            methodChannel.invokeMethod(
                "onMessage",
                mapOf("channel" to channel, "payload" to payload),
            )
        }
    }

    companion object {
        const val NAME = "FlutterBridge"
        private const val TAG = "lynx_view"
    }
}
