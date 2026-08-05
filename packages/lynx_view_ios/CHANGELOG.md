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
