package com.geektree0101.lynx_view_android

import android.content.Context
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

    private val loadListener = object : LynxViewClient() {
        override fun onLoadSuccess() {
            channel.invokeMethod("onLoadSuccess", null)
        }

        override fun onReceivedError(error: LynxError) {
            channel.invokeMethod(
                "onLoadError",
                mapOf("code" to error.errorCode.toString(), "message" to error.msg),
            )
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
        @Suppress("UNCHECKED_CAST")
        lynxView.renderTemplateUrl(templateUrl, (initData ?: emptyMap<String, Any?>()) as Map<String, Any>)
    }

    private fun disposeInternal() {
        LynxViewRegistry.unregister(viewId)
        channel.setMethodCallHandler(null)
        lynxView.removeLynxViewClient(loadListener)
        lynxView.destroy()
    }

    override fun dispose() {
        disposeInternal()
    }
}
