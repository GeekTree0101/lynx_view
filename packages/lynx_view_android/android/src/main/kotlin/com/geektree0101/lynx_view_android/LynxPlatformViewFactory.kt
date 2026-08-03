package com.geektree0101.lynx_view_android

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** viewType this factory answers to — must match the Dart-side platform interface. */
internal const val LYNX_VIEW_TYPE = "com.geektree0101.lynx_view/LynxView"

internal class LynxPlatformViewFactory(
    private val binaryMessenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        LynxViewPlugin.ensureInitialized(context)
        @Suppress("UNCHECKED_CAST")
        val creationParams = args as? Map<String?, Any?>
        return LynxPlatformView(context, viewId, binaryMessenger, creationParams)
    }
}
