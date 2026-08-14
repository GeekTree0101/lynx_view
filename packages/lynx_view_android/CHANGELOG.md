## 1.7.0

* Registers the `fonts` creation param with Lynx before building the
  `LynxView`, so the first measure already resolves the family. Assets are
  looked up through Flutter's own loader (`pubspec.yaml` keys are not the
  paths `AssetManager` wants) and cached in `TypefaceCache`.
* Each family fills all four typeface style slots with the same file.
  `TypefaceCache.getCachedTypeface` answers only for the exact style asked
  for, so a bold family with an empty bold slot would have Lynx synthesize a
  bold on top of an already-bold face.
* A family already in the cache is skipped — decoding a CJK font is tens of
  milliseconds and every platform view creation would otherwise repeat it.

## 1.6.0

* Splits Lynx error reporting by `LynxError.isFatal`: fatal errors keep
  firing `onLoadError`, recoverable ones (image fetch failures, runtime
  warnings) now fire `onReceivedError` and no longer complete a pending
  load. Before this, one 404'd `<image>` killed screens that treat
  `onLoadError` as fatal.

## 1.5.0

* Ships and registers the image service, so `<image>` renders remote
  sources. Lynx delegates all fetch/decode/cache to a registered service
  and silently renders nothing without one. `lynx-service-image` (built on
  Fresco, versions from the official integration guide) is registered
  before `LynxEnv` init, the order the guide uses.
* Fresco is initialized only if the host app has not already done so —
  initializing twice resets Fresco's caches.

## 1.4.0

* Hands XElement's behaviors to every `LynxViewBuilder`, so `<input>` and
  friends actually work. Unlike iOS there is no automatic registration path
  here — adding the Maven dependency alone does nothing. Resolved
  reflectively, so an app that excludes the artifact keeps working.
* Fixed release builds, which failed in R8 with `Missing class
  com.facebook.*` and `com.lynx.markdown.*`. Both are referenced by
  XElement artifacts that do not declare them. `xelement-markdown` is
  excluded outright — its engine is not on Maven, so `<markdown>` could
  never work — and the Fresco references are marked expected, since they
  sit on the remote-image path of `<svg>` that an app opts into by adding
  Fresco itself.

## 1.3.0

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
