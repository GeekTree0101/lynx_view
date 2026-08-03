package com.geektree0101.lynx_view_android

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Registers the `LynxView` platform view factory. All actual Lynx
 * initialization is deferred to [LynxViewPlugin.ensureInitialized], the
 * first time a `LynxView` is created — see that class for why.
 */
class LynxViewAndroidPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory(
            LYNX_VIEW_TYPE,
            LynxPlatformViewFactory(binding.binaryMessenger),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // No teardown needed: individual LynxPlatformView instances clean up
        // their own native LynxView on PlatformView#dispose().
    }
}
