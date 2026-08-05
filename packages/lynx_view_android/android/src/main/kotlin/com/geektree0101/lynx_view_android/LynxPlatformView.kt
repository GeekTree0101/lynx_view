package com.geektree0101.lynx_view_android

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.lynx.react.bridge.JavaOnlyArray
import com.lynx.react.bridge.JavaOnlyMap
import com.lynx.tasm.LynxError
import com.lynx.tasm.LynxView
import com.lynx.tasm.LynxViewBuilder
import com.lynx.tasm.LynxViewClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

private const val INSTANCE_CHANNEL_PREFIX = "com.geektree0101.lynx_view/instance_"

/**
 * Wraps one native [LynxView] as a Flutter [PlatformView] (Hybrid
 * Composition — the default/recommended `AndroidView` embedding mode).
 *
 * Owns the per-instance [MethodChannel] that [lynx_view]'s
 * `LynxViewController` talks to: `reload`/`sendEvent`/`dispose` in, and
 * `onLoadSuccess`/`onLoadError`/`onMessage` out.
 */
internal class LynxPlatformView(
    context: Context,
    private val viewId: Int,
    binaryMessenger: BinaryMessenger,
    creationParams: Map<String?, Any?>?,
) : PlatformView, MethodChannel.MethodCallHandler {

    private val lynxView: LynxView = LynxViewBuilder().build(context)
    private val channel = MethodChannel(binaryMessenger, "$INSTANCE_CHANNEL_PREFIX$viewId")
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Lynx cannot cancel a template load, and two loads running at once on the
     * same [LynxView] race each other into an empty tree. So only one is ever
     * in flight; a request that arrives during one is remembered and runs
     * after it, and only the last one is kept — a burst of `reload()` calls
     * collapses to "load the newest URL", never a pile-up. Main-thread only.
     */
    private var isLoading = false
    private var pendingLoad: Pair<String, Map<String, Any?>?>? = null

    // LynxViewClient callbacks fire off the main thread, but MethodChannel
    // must be invoked on it — posting here matches the fix already applied
    // in FlutterBridgeModule.postMessage.
    private val loadListener = object : LynxViewClient() {
        override fun onLoadSuccess() {
            mainHandler.post {
                if (finishLoad()) return@post
                channel.invokeMethod("onLoadSuccess", null)
            }
        }

        override fun onReceivedError(error: LynxError) {
            mainHandler.post {
                if (finishLoad()) return@post
                channel.invokeMethod(
                    "onLoadError",
                    mapOf("code" to error.errorCode.toString(), "message" to error.msg),
                )
            }
        }
    }

    init {
        // Lets FlutterBridgeModule (constructed per-LynxView by the engine)
        // find its way back to this view's Dart channel.
        lynxView.tag = viewId
        LynxViewRegistry.register(viewId, channel)

        channel.setMethodCallHandler(this)
        lynxView.addLynxViewClient(loadListener)

        val templateUrl = creationParams?.get("templateUrl") as? String
        @Suppress("UNCHECKED_CAST")
        val initData = creationParams?.get("initData") as? Map<String, Any?>
        if (templateUrl != null) {
            load(templateUrl, initData)
        }
    }

    override fun getView() = lynxView

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "reload" -> {
                val templateUrl = call.argument<String>("templateUrl")
                @Suppress("UNCHECKED_CAST")
                val initData = call.argument<Map<String, Any?>>("initData")
                if (templateUrl == null) {
                    result.error("invalid_args", "templateUrl is required", null)
                    return
                }
                load(templateUrl, initData)
                result.success(null)
            }
            "sendEvent" -> {
                val name = call.argument<String>("name")
                @Suppress("UNCHECKED_CAST")
                val args = call.argument<Map<String, Any?>>("args") ?: emptyMap<String, Any?>()
                if (name == null) {
                    result.error("invalid_args", "name is required", null)
                    return
                }
                // Mirrors the iOS `sendGlobalEvent(name, withParams:)` sample
                // from the public docs: a JS listener receives this as an
                // array of positional params, so we send a 1-element array
                // containing the args map.
                lynxView.sendGlobalEvent(name, JavaOnlyArray.from(listOf(JavaOnlyMap.from(args))))
                result.success(null)
            }
            "dispose" -> {
                disposeInternal()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun load(templateUrl: String, initData: Map<String, Any?>?) {
        if (isLoading) {
            pendingLoad = templateUrl to initData
            return
        }
        isLoading = true
        @Suppress("UNCHECKED_CAST")
        lynxView.renderTemplateUrl(templateUrl, (initData ?: emptyMap<String, Any?>()) as Map<String, Any>)
    }

    /**
     * Called when the in-flight load reports back. Returns true if another
     * request came in while it was running — in that case this load's result
     * is stale and must not be reported to Dart, since the newer load is what
     * will actually end up on screen.
     */
    private fun finishLoad(): Boolean {
        isLoading = false
        val next = pendingLoad ?: return false
        pendingLoad = null
        load(next.first, next.second)
        return true
    }

    /**
     * Teardown is reached from two independent paths and both fire in the
     * normal flow: the Dart controller's explicit `dispose()` arrives over the
     * channel, and the engine calls [dispose] when the widget leaves the tree.
     * Without this flag `lynxView.destroy()` runs twice on the same instance.
     */
    private var isDisposed = false

    private fun disposeInternal() {
        if (isDisposed) return
        isDisposed = true
        pendingLoad = null
        LynxViewRegistry.unregister(viewId)
        channel.setMethodCallHandler(null)
        lynxView.removeLynxViewClient(loadListener)
        lynxView.destroy()
    }

    override fun dispose() {
        disposeInternal()
    }
}
