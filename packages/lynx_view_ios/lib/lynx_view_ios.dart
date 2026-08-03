// This package intentionally has no public Dart API of its own.
//
// Its job is to ship the iOS-native side of `lynx_view` (Podspec dependency
// on the Lynx SDK, the `LynxViewIosPlugin` platform view factory,
// `LynxViewPlugin.registerNativeModule`, the built-in `FlutterBridge`
// module) and register itself as the iOS implementation via
// `pubspec.yaml`'s `flutter.plugin.platforms.ios`.
//
// The actual Dart-facing API (`LynxView`, `LynxViewController`) lives in the
// `lynx_view` package; the shared `AndroidView`/`UiKitView` plumbing lives in
// `lynx_view_platform_interface`'s `MethodChannelLynxView`.
