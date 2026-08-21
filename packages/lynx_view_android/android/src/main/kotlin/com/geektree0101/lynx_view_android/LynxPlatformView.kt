package com.geektree0101.lynx_view_android

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import com.lynx.react.bridge.JavaOnlyArray
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

    private val lynxView: LynxView = LynxViewBuilder()
        .also { XElementSupport.addBehaviorsIfPresent(it) }
        // Per-view, not global: this is how the bridge module learns which
        // Flutter view it belongs to. Lynx hands the third argument back as
        // the module's `mParam` when it constructs it, and a wrapper
        // registered here wins over anything on LynxEnv. See
        // [FlutterBridgeModule] for why reading it off the LynxView cannot
        // work on Android.
        .also {
            it.registerModule(
                FlutterBridgeModule.NAME,
                FlutterBridgeModule::class.java,
                viewId,
            )
        }
        .build(context)
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

    /** Whether Flutter has given this view a real size yet — see [load]. */
    private var hasViewport = false

    /**
     * Fires on every layout pass; only the first one with a real size matters,
     * and it takes itself off the view once it has seen it.
     *
     * By the time this runs, Lynx already knows the size: [LynxView.onMeasure]
     * hands the measure specs to `updateViewport`, and measure runs before
     * layout. So there is nothing to report here — only a load to release.
     */
    private val firstLayoutListener = object : View.OnLayoutChangeListener {
        override fun onLayoutChange(
            v: View,
            left: Int,
            top: Int,
            right: Int,
            bottom: Int,
            oldLeft: Int,
            oldTop: Int,
            oldRight: Int,
            oldBottom: Int,
        ) {
            if (right - left <= 0 || bottom - top <= 0) return
            v.removeOnLayoutChangeListener(this)
            onViewportReady()
        }
    }

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
            // Lynx reports every error here — a template that failed to load,
            // but also an <image> src that 404'd or a runtime warning. Only
            // the fatal ones mean the view is broken; forwarding the rest as
            // "onLoadError" made consumers kill screens over a single missing
            // thumbnail. LynxError knows the difference.
            mainHandler.post {
                if (!error.isFatal) {
                    channel.invokeMethod(
                        "onReceivedError",
                        mapOf("code" to error.errorCode.toString(), "message" to error.msg),
                    )
                    return@post
                }
                if (finishLoad()) return@post
                channel.invokeMethod(
                    "onLoadError",
                    mapOf("code" to error.errorCode.toString(), "message" to error.msg),
                )
            }
        }
    }

    init {
        // Lets FlutterBridgeModule — which the engine builds per LynxView with
        // this view's id as its param — find its way back to this view's Dart
        // channel.
        LynxViewRegistry.register(viewId, channel)

        channel.setMethodCallHandler(this)
        lynxView.addLynxViewClient(loadListener)
        // Before the first load is even requested — that request is going to
        // be held until this listener fires.
        lynxView.addOnLayoutChangeListener(firstLayoutListener)

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
                lynxView.sendGlobalEvent(name, JavaOnlyArray().apply { add(toLynxValue(args)) })
                result.success(null)
            }
            "dispose" -> {
                disposeInternal()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Two things hold a load back, and both mean the same thing: not yet.
     *
     * One is another load still running — see [pendingLoad]. The other is not
     * knowing how big this view is. A Flutter platform view is created before
     * it is placed, so at that moment it has no size, and a template laid out
     * against a zero viewport stays collapsed in the top-left: Lynx resolves
     * `%`, `flex` and `vh` while laying out and does not redo that on its own
     * afterwards. Waiting costs one frame — the load itself takes far longer
     * than that — and buys a first paint that is already correct.
     *
     * Either way the newest request wins, and it runs as soon as the reason to
     * wait is gone.
     */
    private fun load(templateUrl: String, initData: Map<String, Any?>?) {
        if (isLoading || !hasViewport) {
            pendingLoad = templateUrl to initData
            return
        }
        isLoading = true
        @Suppress("UNCHECKED_CAST")
        lynxView.renderTemplateUrl(templateUrl, (initData ?: emptyMap<String, Any?>()) as Map<String, Any>)
    }

    /**
     * The view has been placed and Lynx knows its size. Whatever was held for
     * that runs now.
     *
     * A view that Flutter never gives a size to never loads — a `LynxView` in
     * a zero-height box, say. That is the intended reading of "wait for the
     * size", and it renders nothing either way.
     */
    private fun onViewportReady() {
        if (hasViewport) return
        hasViewport = true

        val next = pendingLoad ?: return
        pendingLoad = null
        load(next.first, next.second)
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
        lynxView.removeOnLayoutChangeListener(firstLayoutListener)
        lynxView.destroy()
    }

    override fun dispose() {
        disposeInternal()
    }
}
