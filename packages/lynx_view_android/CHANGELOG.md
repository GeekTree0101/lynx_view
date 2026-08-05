## 1.1.0

* Fixed `LynxView.destroy()` running twice on the same instance — the channel
  teardown and the engine's `PlatformView.dispose()` both reach it.
* Answer `trimMemory` and `queryMemoryUsage` on the plugin channel, forwarding
  to `LynxEnv.trimMemory` and `LynxMemoryUsageQuery`.

## 1.0.0

* Initial release: Android implementation of `lynx_view` (Lynx SDK 4.0.0 Gradle deps, `LynxPlatformViewFactory`, `LynxViewPlugin.registerNativeModule`, built-in `FlutterBridge` module).
