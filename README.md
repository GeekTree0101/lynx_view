# lynx_view

Wraps [LynxJS](https://lynxjs.org)'s native `LynxView` as a Flutter `PlatformView`, so an existing Flutter app can embed Lynx templates.

📖 한국어 문서: [docs/ko](docs/ko/README.md)

## Features

- Renders a remote Lynx bundle (`templateUrl`) inside a Flutter widget, Android and iOS.
- Runtime `reload()` — the hook an OTA/CodePush-style client uses to swap in a new bundle without recreating the widget.
- Built-in `FlutterBridge` channel — JS &lt;-&gt; Dart messaging (`addJavaScriptChannel`/`sendEvent`) with **no native code required**.
- Escape hatch for custom native modules (`LynxViewPlugin.registerNativeModule`) when you need something typed/native.
- Memory-aware: the platform's memory-pressure signal is forwarded to Lynx automatically, and `LynxMemory.usage()` reports what each live view is actually holding.

This package does **not** provide OTA/CodePush server infrastructure, bundle caching, or Web/Desktop/HarmonyOS support — see the techspec for scope boundaries.

## Getting started

### 1. Add the dependency

```yaml
dependencies:
  lynx_view: ^1.3.0
```

### 2. Android setup

No manual Gradle changes needed — the plugin brings its own Lynx SDK dependency. `minSdkVersion` is enforced at 21 by the plugin (Lynx SDK 4.0.0's own floor).

If you need a custom native module, register it once at app startup:

```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        LynxViewPlugin.registerNativeModule("YourCustomModule", YourCustomModule::class.java)
    }
}
```

### 3. iOS setup

No manual Podfile changes needed. In Xcode, set **User Script Sandboxing** to `NO` (a Lynx SDK build requirement).

If you need a custom native module, register it in `AppDelegate`:

```swift
@main
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    LynxViewPlugin.registerNativeModule("YourCustomModule", moduleClass: YourCustomModule.self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

> **CocoaPods only, no Swift Package Manager yet.** `lynx_view_ios` depends on the `Lynx`/`PrimJS` pods, and Lynx itself isn't distributed via SPM upstream ([lynx-family/lynx#162](https://github.com/lynx-family/lynx/issues/162) is an open, unanswered feature request). Since a Flutter SPM plugin can't mix in a CocoaPods-only native dependency, this package can't support SPM until Lynx does.

## Usage

### Render a bundle

```dart
class _LynxScreenState extends State<LynxScreen> {
  late final LynxViewController _controller = LynxViewController(
    templateUrl: 'https://your-bucket.s3.amazonaws.com/bundles/home.lynx.bundle',
    initData: const {'userId': '123'},
    onLoadSuccess: () => debugPrint('Lynx bundle loaded'),
    onLoadError: (e) => debugPrint('Lynx load failed: ${e.code} ${e.message}'),
  );

  @override
  Widget build(BuildContext context) => LynxView(controller: _controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

### JS &lt;-&gt; Dart messaging without native code

```dart
_controller.addJavaScriptChannel(
  'MyChannel',
  onMessageReceived: (LynxMessage message) => debugPrint('from JS: ${message.data}'),
);
_controller.sendEvent('MyChannel', {'greeting': 'hello from Flutter'});
```

```js
// bundle JS
NativeModules.FlutterBridge.postMessage('MyChannel', JSON.stringify({ hello: 'from lynx' }));
lynx.getJSModule('GlobalEventEmitter').addListener('MyChannel', (data) => console.log('from Flutter:', data));
```

### Reloading (OTA/CodePush integration point)

This package doesn't ship OTA infrastructure — it just gives your own OTA/CodePush client something to call:

```dart
Future<void> onNewBundleAvailable(String newTemplateUrl) async {
  await _controller.reload(newTemplateUrl);
}
```

If a reload fails, the previously rendered content stays on screen and `onLoadError` fires — no crash, no automatic rollback.

### Memory

A `LynxView` is not a cheap widget: each one owns an engine, a JS runtime, an
element tree and its own image cache, and all of it lives in **your app's
process** — unlike a `WKWebView`, whose content sits in a separate process the
OS bills separately. Two things follow from that, and the package handles the
first for you.

**Pressure is forwarded automatically.** Flutter surfaces the platform's
memory warning (`applicationDidReceiveMemoryWarning` on iOS, `onTrimMemory` on
Android); this package relays it to Lynx so live views shed their caches instead
of holding on until the system kills the app. Nothing to wire up — the relay is
active only while a `LynxView` is mounted. Trigger it yourself if you need to:

```dart
await LynxMemory.trim(LynxMemoryPressureLevel.critical);
```

**And you can ask where the memory went**, rather than inferring it from RSS
(which measures something else — it counts mapped shared libraries, and can run
well above the footprint the OS actually holds you to):

```dart
final usage = await LynxMemory.usage();
usage.appBytes;                     // the app's physical footprint
usage.totalBytes;                   // what Lynx accounts for within it
usage.elementBytes;                 // element tree
usage.viewBytes;                    // platform views Lynx created
usage.mainThreadRuntimeBytes;       // main-thread JS (PrimJS)
usage.backgroundThreadRuntimeBytes; // background JS — JSC on iOS
usage.instances;                    // the same, per live view
```

Disposing matters more than instance count. A handful of views is a few percent
of a modern phone's budget, but a view that never releases grows without bound —
so call `controller.dispose()`, and prefer dropping views you can cheaply
rebuild over keeping them alive off-screen.

See the `example/` app for a complete, runnable demo.

## Additional information

Source, issue tracker, and design notes: https://github.com/GeekTree0101/lynx_view
