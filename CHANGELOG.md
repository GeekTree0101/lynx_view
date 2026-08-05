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
