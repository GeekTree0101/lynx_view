## 1.7.3

* Completes the Android bridge fix started in 1.7.2. That release repaired the
  JS -> Dart direction; this one repairs the reply. 1.7.2 said the other
  direction was fine — that holds only for flat payloads. `sendEvent` handed
  Lynx its arguments with a top-level-only conversion, so any nested object or
  list inside them was passed through as a plain Java `Map`/`List` and rejected
  when Lynx read it back, with the exception swallowed and the bundle seeing
  only `cannot convert to object`.
* So a bundle using `addJavaScriptChannel` for request/response still hung
  after 1.7.2: the request reached Dart, and the reply envelope
  (`{id, ok, result}`) never arrived, because `result` is a structured object
  by definition. Verified on a real screen whose every data call goes through
  that protocol.
* Requires `lynx_view_android` 1.7.2. iOS is unaffected and unchanged.

## 1.7.2

* Fixes the JS -> Dart bridge on Android, which had never worked. A bundle
  calling `NativeModules.FlutterBridge.postMessage(...)` had its message
  dropped without a log, so `addJavaScriptChannel` never fired and any
  request/response protocol built on top of it hung forever. The other
  direction (`sendEvent`, via `GlobalEventEmitter`) was fine, so screens
  rendered and only the calls into the app went missing. iOS was unaffected
  and needs no change.
* The cause was how the native module found the Flutter view it belonged to:
  it asked `LynxContext` for its `LynxView` and read the id off the view's
  tag. Neither half answers on Android — Lynx 4.0.0 never calls
  `LynxContext.setLynxView()` anywhere in the SDK, and `LynxView` overrides
  `getTag()` to return the constant `"lynxview"`. On iOS the same code works
  because a `LynxView` is a `UIView` whose `tag` really is an integer.
* The view id is now handed to the module when it is built, through Lynx's
  per-view module registration, so nothing has to be read back off the view.
  Dropped messages are logged instead of swallowed, and the routing is
  covered by unit tests that need no live `LynxView`.

## 1.7.1

* Fixes the iOS build. 1.7.0's font registration called the Objective-C
  selectors as written in Lynx's header — `sharedManager()` and
  `registerFont(_:forName:)` — but the header carries no `NS_SWIFT_NAME`, so
  Swift's automatic renaming applies and the real names are `shared()` and
  `register(_:forName:)`. Any app on 1.7.0 fails to compile for iOS with
  "'sharedManager()' has been renamed to 'shared()'". Android was unaffected.

## 1.7.0

* Fonts. A template could name a `font-family` and never get one: Lynx does
  not load fonts by itself — `@font-face src: url()` is delegated to a
  resource fetcher this package does not ship, and the built-in loader
  understands only `local()` and inline `data:` URIs — so every custom family
  fell through to the system font, silently, the same failure shape the image
  service had before 1.5.0. `LynxViewController` now takes `fonts:`, a list of
  `LynxFontAsset(family:, assetPath:)`, and the native side registers those
  Flutter assets with Lynx while the view is being created, before the first
  template load.
* Nothing is fetched. A host app that already ships a typeface for its own UI
  hands Lynx the same asset — no CDN to stand up, no download in front of the
  first paint, and no drift between what Flutter draws and what a template
  draws. Fonts declared under `fonts:` in the host's `pubspec.yaml` are in the
  asset bundle already, so there is no second copy.
* One family is one weight. Lynx resolves `font-family` by name alone: it has
  no way to choose between weights registered under one name, and on Android
  every CSS weight from 500 up collapses into a single "bold" slot
  (`TextAttributes.isFontWeightBOLD`). Register `Pretendard-Regular` and
  `Pretendard-Bold` as two families and let the template pick with
  `font-family` rather than `font-weight`.
* Registration is per-process and idempotent — re-listing a family on a later
  view skips the decode rather than repeating it. A font that will not load is
  skipped with a log; the screen keeps rendering in the system font, exactly
  as it did before.

## 1.6.0

* Recoverable errors no longer arrive as `onLoadError`. Lynx reports every
  error through one native callback — a template that failed to load, but
  also an `<image>` src that 404'd or a runtime warning. 1.5.0's image
  pipeline made the latter kind common, and consumers treating
  `onLoadError` as fatal started killing whole screens over one missing
  thumbnail. Fatal errors (LynxError's own `isFatal`) keep firing
  `onLoadError`; everything else goes to the new optional
  `onReceivedError` callback, for logging rather than teardown.

## 1.5.0

* `<image>` now renders remote sources. Lynx delegates all image fetching,
  decoding and caching to a host-registered image service, and renders
  nothing — silently — when there is none; this package never shipped one,
  so every remote `src` came out as an empty box. Android now ships
  `lynx-service-image` on Fresco and registers it before `LynxEnv` init;
  iOS pulls `LynxService/Image` (SDWebImage-backed), which self-registers
  at load.
* Images are cached by those native libraries' own memory and disk caches.
  Nothing is shared with the host app's image stack (e.g. Flutter's
  `CachedNetworkImage`) — a URL seen by both sides is fetched once per side.
* On Android, Fresco is initialized by the plugin only if the host app has
  not already done so — initializing twice resets Fresco's caches.

## 1.4.0

* XElement's elements — `<input>`, `<textarea>`, `<svg>`, `<overlay>`,
  `<viewpager>`, `<refresh>` and the rest — now work. Lynx's core registers
  only 13 UI elements and leaves everything else to XElement, which this
  package did not ship. A template using `<input>` loaded successfully,
  rendered an empty box, and never took focus, with nothing in the log:
  Lynx skips tags it does not recognise silently.
* Fixed release builds on Android, which failed in R8 once XElement was
  added. Two of its artifacts reference libraries they do not declare —
  Fresco, from the remote-image path of `<svg>`, and the Serval markdown
  engine, which is not published to Maven at all.
* `<markdown>` remains unsupported on both platforms. On iOS its subspec
  pulls statically linked binaries that CocoaPods refuses under the
  `use_frameworks!` every Flutter Podfile declares; on Android its engine
  does not exist as an artifact. The dependency is excluded rather than
  shipped as dead code.
* `<svg>` renders inline sources out of the box. Loading one from a remote
  URL goes through Fresco, which an app wanting that must add itself —
  Lynx expects the host to supply its own image service.

## 1.3.0

* The example app now uses `com.example.*` identifiers, the same as a fresh
  `flutter create`. It carried the maintainer's own reverse-DNS prefix for no
  reason, which is not what someone cloning the example wants to inherit.

## 1.2.1

* Removed the maintainer's Apple `DEVELOPMENT_TEAM` from the example project —
  it served no purpose in a template and only produced signing errors for
  anyone building the example under their own account.
* README now documents the memory APIs added in 1.2.0 and points at
  `docs/ko/memory.md`; the 1.2.0 listing still described the 1.0.0 surface.

## 1.2.0

* **Fixed: Android release builds failed with R8.** Lynx references Gson from
  `LynxEnv.GetNativeEnvDebugDescription()` without depending on it, so every
  consuming app's `assembleRelease` died with `Missing class
  com.google.gson.Gson`. The plugin now ships a consumer ProGuard rule, so apps
  need no workaround of their own. Debug builds never showed this.

* **Fixed (iOS): the native `LynxView` was never explicitly torn down.** Release
  was left entirely to ARC, and because Lynx holds internal references of its
  own the engine could outlive `dispose()` indefinitely — memory measured after
  tearing down five views went *up*, not down. `clearForDestroy` is now called,
  which makes release deterministic; the same measurement now reclaims what it
  allocated.
* **Fixed (Android): `destroy()` ran twice on the same native view.** Both the
  controller's explicit `dispose()` and the engine's `PlatformView.dispose()`
  reach the same teardown path in the normal flow, and nothing guarded against
  the second pass.
* **Added `LynxMemory.trim()`.** Flutter already surfaces the platform's
  memory-pressure signal and Lynx already exposes `LynxEnv.trimMemory`, but
  nothing connected the two — a live `LynxView` held its caches right up to the
  moment the system killed the app. The relay installs itself only while a
  `LynxView` is mounted.
* **Added `LynxMemory.usage()`.** Per-instance memory attribution (element tree,
  platform views, main-thread and background JS runtimes) plus the app's own
  physical footprint, so "where does a LynxView's memory go" is answerable
  without guessing from RSS.

## 1.0.0

* Initial release: `LynxView` widget and `LynxViewController` for embedding LynxJS (https://lynxjs.org) templates in Flutter apps via a native PlatformView.
