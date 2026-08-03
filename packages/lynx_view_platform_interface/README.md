# lynx_view_platform_interface

A common platform interface for [`lynx_view`](https://pub.dev/packages/lynx_view). App developers should depend on `lynx_view` directly, not this package.

Defines `LynxViewPlatform` (implemented by `lynx_view_android`/`lynx_view_ios`) and the shared `MethodChannelLynxView` used by both — the `AndroidView`/`UiKitView` selection and per-instance `MethodChannel` plumbing live here once instead of being duplicated per platform.
