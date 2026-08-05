## 1.2.1

* The example app now uses `com.example.*` identifiers instead of the
  maintainer's own reverse-DNS prefix.

## 1.2.0

* **Fixed: R8 broke consuming apps' release builds** on a dangling Gson
  reference inside Lynx. Ships `consumer-rules.pro` with `-dontwarn
  com.google.gson.**`.

* Fixed `LynxView.destroy()` running twice on the same instance — the channel
  teardown and the engine's `PlatformView.dispose()` both reach it.
* Answer `trimMemory` and `queryMemoryUsage` on the plugin channel, forwarding
  to `LynxEnv.trimMemory` and `LynxMemoryUsageQuery`.

## 1.0.0

* Initial release: Android implementation of `lynx_view` (Lynx SDK 4.0.0 Gradle deps, `LynxPlatformViewFactory`, `LynxViewPlugin.registerNativeModule`, built-in `FlutterBridge` module).
