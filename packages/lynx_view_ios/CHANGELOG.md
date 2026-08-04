## 1.0.1

* Keep Lynx's viewport in sync with the size Flutter gives the platform view. A platform view is created before its size is known, and Lynx was never told the real bounds that arrived afterwards — so templates laid out against a zero viewport, which collapsed `flex: 1` to nothing and left `%`/`vh` sizes unresolved.

## 1.0.0

* Initial release: iOS implementation of `lynx_view` (Lynx SDK 4.0.0 CocoaPods deps, `LynxPlatformViewFactory`, `LynxViewPlugin.registerNativeModule`, built-in `FlutterBridge` module).
