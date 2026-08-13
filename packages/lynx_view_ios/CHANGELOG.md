## 1.6.0

* Splits Lynx error reporting by `LynxError.isFatal`: fatal errors keep
  firing `onLoadError`, recoverable ones (image fetch failures, runtime
  warnings) now fire `onReceivedError` and no longer complete a pending
  load. Before this, one 404'd `<image>` killed screens that treat
  `onLoadError` as fatal.

## 1.5.0

* Pulls `LynxService/Image` so `<image>` renders remote sources. Lynx
  delegates all fetch/decode/cache to a registered image service and
  silently renders nothing without one. Unlike XElement there is no
  registration code to write: `LynxImageService.m` self-registers at load
  via the `LynxServiceRegister` macro, and the subspec pins its own
  SDWebImage versions.

## 1.4.0

* Registers XElement's elements so `<input>` and friends actually work.
  The elements ship in one set of subspecs and the code that binds them to
  tag names ships in another, `XElement/Behavior` — which depends on
  `XElement/Markdown`, which pulls the statically linked `ServalMarkdown`
  and `LynxTextra`. CocoaPods rejects those under `use_frameworks!`, so the
  classes linked but stayed unreachable. `LynxXElementRegistry` now makes
  the same `LynxComponentRegistry` calls the upstream macros expand to,
  looking classes up by name so an excluded subspec registers nothing
  rather than failing to link.

## 1.3.0

* Version aligned across the federated packages so they move in lockstep; no
  functional change in this one.

## 1.2.1

* Removed the maintainer's Apple `DEVELOPMENT_TEAM` from the example project.

## 1.2.0

* Fixed: the native `LynxView` is now released with Lynx's own `clearForDestroy`
  instead of relying on ARC alone, which could leave the engine alive well past
  `dispose()`.
* Answer `trimMemory` and `queryMemoryUsage` on the plugin channel, forwarding
  to `LynxEnv.trimMemory` and `LynxMemoryUsageQuery`.

## 1.0.1

* Keep Lynx's viewport in sync with the size Flutter gives the platform view. A platform view is created before its size is known, and Lynx was never told the real bounds that arrived afterwards — so templates laid out against a zero viewport, which collapsed `flex: 1` to nothing and left `%`/`vh` sizes unresolved.

## 1.0.0

* Initial release: iOS implementation of `lynx_view` (Lynx SDK 4.0.0 CocoaPods deps, `LynxPlatformViewFactory`, `LynxViewPlugin.registerNativeModule`, built-in `FlutterBridge` module).
