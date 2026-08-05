package com.geektree0101.lynx_view_android

import android.os.Handler
import android.os.Looper
import com.lynx.tasm.LynxEnv
import com.lynx.tasm.LynxGlobalMemoryUsageResult
import com.lynx.tasm.LynxInstanceMemoryUsage
import com.lynx.tasm.LynxMemoryCollectionStatus
import com.lynx.tasm.LynxGlobalMemoryUsageCallback
import com.lynx.tasm.LynxMemoryUsageQuery
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Channel for calls that aren't about one particular view. */
private const val PLUGIN_CHANNEL = "com.geektree0101.lynx_view/plugin"

/**
 * Registers the `LynxView` platform view factory and the process-wide plugin
 * channel. All actual Lynx initialization is deferred to
 * [LynxViewPlugin.ensureInitialized], the first time a `LynxView` is created —
 * see that class for why.
 */
class LynxViewAndroidPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var pluginChannel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory(
            LYNX_VIEW_TYPE,
            LynxPlatformViewFactory(binding.binaryMessenger),
        )
        pluginChannel = MethodChannel(binding.binaryMessenger, PLUGIN_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "trimMemory" -> {
                val level = call.argument<Int>("level")
                if (level == null) {
                    result.error("invalid_args", "level is required", null)
                    return
                }
                // LynxEnv is only created once the first LynxView is built. A
                // pressure signal before that has nothing to act on, and
                // touching LynxEnv here would initialize it for no reason.
                if (LynxViewPlugin.isInitialized()) {
                    LynxEnv.inst().trimMemory(level)
                }
                result.success(null)
            }
            "queryMemoryUsage" -> {
                if (!LynxViewPlugin.isInitialized()) {
                    // Nothing has been rendered yet, so Lynx accounts for
                    // nothing. Answering with an empty snapshot beats forcing
                    // LynxEnv into existence just to report zeroes.
                    result.success(emptyUsage())
                    return
                }
                val timeoutMs = (call.argument<Number>("timeoutMs"))?.toLong() ?: 0L
                LynxMemoryUsageQuery.inst().queryLynxGlobalMemoryUsageAsync(
                    object : LynxGlobalMemoryUsageCallback() {
                        override fun onResult(usage: LynxGlobalMemoryUsageResult) {
                            // Lynx answers on its own report thread; MethodChannel
                            // results must be delivered on the main thread.
                            mainHandler.post { result.success(usage.toMap()) }
                        }
                    },
                    timeoutMs,
                )
            }
            else -> result.notImplemented()
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private fun emptyUsage(): Map<String, Any?> = mapOf(
        "totalBytes" to 0L,
        "appBytes" to 0L,
        "ratioToApp" to 0.0,
        "elementBytes" to 0L,
        "elementNodeCount" to 0L,
        "viewBytes" to 0L,
        "mainThreadRuntimeBytes" to 0L,
        "backgroundThreadRuntimeBytes" to 0L,
        "expectedInstanceCount" to 0,
        "completedInstanceCount" to 0,
        "timedOut" to false,
        "instances" to emptyList<Map<String, Any?>>(),
    )

    private fun LynxGlobalMemoryUsageResult.toMap(): Map<String, Any?> = mapOf(
        "totalBytes" to totalBytes,
        "appBytes" to appBytes,
        "ratioToApp" to ratioToApp,
        "elementBytes" to elementBytes,
        "elementNodeCount" to elementNodeCount,
        "viewBytes" to viewBytes,
        "mainThreadRuntimeBytes" to mainThreadRuntimeBytes,
        "backgroundThreadRuntimeBytes" to backgroundThreadRuntimeBytes,
        "expectedInstanceCount" to expectedInstanceCount,
        "completedInstanceCount" to completedInstanceCount,
        "timedOut" to (collectionStatus == LynxMemoryCollectionStatus.TIMEOUT),
        "instances" to instances.map { it.toMap() },
    )

    private fun LynxInstanceMemoryUsage.toMap(): Map<String, Any?> = mapOf(
        "instanceId" to instanceId,
        "url" to url,
        "totalBytes" to totalBytes,
        "elementBytes" to elementBytes,
        "elementNodeCount" to elementNodeCount,
        "viewBytes" to viewBytes,
        "mainThreadRuntimeBytes" to mainThreadRuntimeBytes,
        "backgroundThreadRuntimeBytes" to backgroundThreadRuntimeBytes,
        "backgroundRuntimeGroupId" to btsRuntimeGroupId,
    )

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Individual LynxPlatformView instances clean up their own native
        // LynxView on PlatformView#dispose(); only the shared channel is ours.
        pluginChannel?.setMethodCallHandler(null)
        pluginChannel = null
    }
}
