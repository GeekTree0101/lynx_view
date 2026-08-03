// This package intentionally has no public Dart API of its own.
//
// Its job is to ship the Android-native side of `lynx_view` (Gradle
// dependency on the Lynx SDK, the `LynxViewAndroidPlugin` platform view
// factory, `LynxViewPlugin.registerNativeModule`, the built-in
// `FlutterBridge` module) and register itself as the Android implementation
// via `pubspec.yaml`'s `flutter.plugin.platforms.android`.
//
// The actual Dart-facing API (`LynxView`, `LynxViewController`) lives in the
// `lynx_view` package; the shared `AndroidView`/`UiKitView` plumbing lives in
// `lynx_view_platform_interface`'s `MethodChannelLynxView`.
