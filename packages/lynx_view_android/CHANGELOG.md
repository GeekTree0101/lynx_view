## 1.8.0

* The first template load now waits until the view has been laid out with a
  real size. A platform view is created before it is placed, so the load ran
  against a viewport of nothing. Lynx resolves `%`, `flex` and `vh` while it
  lays out and does not redo that on its own, so the template stayed collapsed
  in the top-left — a spinner pinned to the corner, then a blank screen.
* Nothing has to be measured here to make that work. `LynxView.onMeasure`
  already hands its measure specs to `updateViewport`, and measure runs before
  layout — so by the first layout pass with a real size, Lynx knows the
  viewport and the load simply starts there. A one-shot
  `OnLayoutChangeListener` is the whole mechanism.
* Holding the load reuses the machinery that already holds one behind an
  in-flight load: newest request wins, and a `reload()` that arrives before
  the size is queued rather than dropped. The wait is about a frame, against a
  load that takes far longer.
* Behavior change worth knowing: a `LynxView` that Flutter never gives a size
  to never loads its bundle. Parking one in a zero-height box no longer
  pre-warms it — it rendered nothing either way.

## 1.7.2

* Fixes `sendEvent` for any payload that is not flat. `JavaOnlyMap.from` and
  `JavaOnlyArray.from` copy their entries across without converting them, so a
  nested `Map`/`List` — what Flutter's `StandardMessageCodec` decodes into —
  stayed a `LinkedHashMap`/`ArrayList` that Lynx cannot read. It blew up later,
  when Lynx read the value back: `JavaOnlyMap.getType` throws
  `IllegalArgumentException: Invalid value {...} for key ... contained in
  JavaOnlyMap`, nothing on that path catches it, and the bundle only ever saw
  `cannot convert to object` while its listener never fired.
* This is the other half of the bridge 1.7.1 repaired. With inbound routing
  fixed, a request/response protocol built on `postMessage` + `sendEvent` still
  could not complete: the request arrived, and the reply — `{id, ok, result}`,
  whose `result` is by nature a structured object — was dropped on the way out.
* Payloads are now deep-converted to Lynx's own container types
  (`toLynxValue`), leaves untouched. Covered by unit tests that need no live
  `LynxView`.

## 1.7.1

* `FlutterBridgeModule` now receives its Flutter view id as a constructor
  param, registered per view on `LynxViewBuilder`, instead of looking it up
  through `LynxContext.getLynxView()` and `LynxView.getTag()`. Neither of
  those answers on Android — the SDK has no call site for
  `LynxContext.setLynxView()`, and `LynxView.getTag()` is overridden to
  return the constant `"lynxview"` — so the lookup produced null and every
  JS -> Dart message was dropped. Silently: both failure paths were bare
  `return`s, which is why a bridge that never worked looked like it did.
* Dropped messages are reported through `LLog` now, and the routing has unit
  tests. Taking the id as a param is what makes those tests possible at all
  — resolving it no longer needs a live `LynxView`.
* `LynxEnv` no longer carries a global `FlutterBridge` registration. One
  registration path, and it is the one that knows which view it serves.
  App-authored modules via `LynxViewPlugin.registerNativeModule` are
  unchanged and stay global.

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
