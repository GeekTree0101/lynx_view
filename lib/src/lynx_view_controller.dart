import 'dart:async';

import 'package:lynx_view_platform_interface/lynx_view_platform_interface.dart';

typedef LynxLoadSuccessCallback = void Function();
typedef LynxLoadErrorCallback = void Function(LynxLoadError error);
typedef LynxMessageHandler = void Function(LynxMessage message);

/// Owns one native `LynxView` instance for its lifetime, following the same
/// ownership pattern as [TextEditingController]/`VideoPlayerController`:
/// create it, pass it to a [LynxView] widget, and call [dispose] yourself
/// (e.g. from `State.dispose`) when you're done with it.
///
/// Every method that talks to the native view (`reload`, `sendEvent`) is
/// safe to call before the underlying `LynxView` has actually been created —
/// calls are queued and flushed once the native view exists. Methods that
/// only touch Dart-side state (`addJavaScriptChannel`,
/// `removeJavaScriptChannel`) take effect immediately regardless of native
/// readiness.
class LynxViewController {
  LynxViewController({
    required String templateUrl,
    this.initData,
    this.fonts = const <LynxFontAsset>[],
    this.onLoadSuccess,
    this.onLoadError,
    this.onReceivedError,
  }) : _templateUrl = templateUrl {
    _eventHandler = _LynxViewControllerEventHandler(this);
  }

  /// The data passed to the JS bundle as `initData` on the initial load.
  final Map<String, dynamic>? initData;

  /// Fonts made available to the template under their [LynxFontAsset.family]
  /// names.
  ///
  /// Lynx draws with the system font unless the host hands it a typeface, so
  /// a template that names a font nobody registered renders in the platform
  /// default with no error. Registration happens natively while the view is
  /// being created — before the first template load — so the very first paint
  /// already has the font; nothing here is fetched over the network.
  ///
  /// Fonts registered here stay registered for the process, and re-listing
  /// one on a later view is a no-op rather than a second decode.
  final List<LynxFontAsset> fonts;

  /// Called every time a template finishes loading successfully (initial
  /// load and every [reload]).
  final LynxLoadSuccessCallback? onLoadSuccess;

  /// Called when a template fails to load. The previously rendered content
  /// (if any) is left on screen — this package never blanks the view or
  /// retries automatically.
  final LynxLoadErrorCallback? onLoadError;

  /// Called for recoverable errors the view survived — an `<image>` src that
  /// 404'd, a runtime warning. The rendered content stays on screen, so this
  /// is for logging/observability, not for tearing the view down. Treating
  /// these as fatal is exactly the failure mode this callback exists to
  /// avoid: one missing thumbnail must not kill a whole screen.
  final LynxLoadErrorCallback? onReceivedError;

  /// The template URL currently (successfully) rendered by the native view.
  /// Only updated once a [reload] actually succeeds — if it fails, this
  /// keeps pointing at whatever is still on screen, matching [onLoadError]'s
  /// "leave the previous content in place" behavior.
  String get templateUrl => _templateUrl;
  String _templateUrl;

  late final LynxViewEventHandler _eventHandler;
  int? _viewId;
  bool _disposed = false;
  final List<Future<void> Function()> _pendingCalls = <Future<void> Function()>[];
  final Map<String, LynxMessageHandler> _channels = <String, LynxMessageHandler>{};

  /// Creation params handed to the native `PlatformViewFactory`. Internal —
  /// used by [LynxView].
  Map<String, dynamic> get creationParams => <String, dynamic>{
        'templateUrl': _templateUrl,
        'initData': initData,
        'fonts': <Map<String, Object?>>[
          for (final LynxFontAsset font in fonts) font.toMap(),
        ],
      };

  /// Wires this controller to the native view identified by [viewId] and
  /// flushes any calls made before it existed. Internal — called by
  /// [LynxView]'s state once `onPlatformViewCreated` fires.
  void attach(int viewId) {
    _checkNotDisposed();
    _viewId = viewId;
    LynxViewPlatform.instance.setEventHandler(viewId, _eventHandler);
    final List<Future<void> Function()> pending =
        List<Future<void> Function()>.from(_pendingCalls);
    _pendingCalls.clear();
    for (final Future<void> Function() call in pending) {
      unawaited(call());
    }
  }

  /// Loads a new template, replacing whatever is currently shown. Safe to
  /// call from an OTA/CodePush-style client the moment it learns of a new
  /// bundle URL — no need to wait for the widget to be mounted.
  Future<void> reload(String templateUrl, {Map<String, dynamic>? initData}) {
    return _runOrQueue(() async {
      await LynxViewPlatform.instance.reload(
        _viewId!,
        templateUrl: templateUrl,
        initData: initData,
      );
      _templateUrl = templateUrl;
    });
  }

  /// Broadcasts a Dart -> JS event via Lynx's `GlobalEventEmitter`. On the
  /// JS side: `lynx.getJSModule('GlobalEventEmitter').addListener(name, ...)`.
  Future<void> sendEvent(String name, Map<String, dynamic> args) {
    return _runOrQueue(
      () => LynxViewPlatform.instance.sendEvent(_viewId!, name: name, args: args),
    );
  }

  /// Registers a handler for JS -> Dart messages sent through the built-in
  /// `FlutterBridge` channel named [name] — no custom native module required
  /// on the JS side: `NativeModules.FlutterBridge.postMessage(name, payload)`.
  ///
  /// Dart-side registration only; takes effect immediately even before the
  /// native view exists.
  void addJavaScriptChannel(
    String name, {
    required LynxMessageHandler onMessageReceived,
  }) {
    _checkNotDisposed();
    _channels[name] = onMessageReceived;
  }

  /// Stops listening on the `FlutterBridge` channel named [name].
  void removeJavaScriptChannel(String name) {
    _channels.remove(name);
  }

  /// Releases the native `LynxView` resources owned by this controller. The
  /// single, explicit point of native cleanup — does not rely on the
  /// `LynxView` widget being unmounted. Call this yourself once you're done
  /// with the controller (typically from `State.dispose`). Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pendingCalls.clear();
    _channels.clear();
    final int? viewId = _viewId;
    if (viewId == null) return;
    await LynxViewPlatform.instance.dispose(viewId);
  }

  Future<void> _runOrQueue(Future<void> Function() action) {
    _checkNotDisposed();
    if (_viewId != null) {
      return action();
    }
    final Completer<void> completer = Completer<void>();
    _pendingCalls.add(() async {
      try {
        await action();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('LynxViewController was used after being disposed.');
    }
  }

  void _handleLoadSuccess() => onLoadSuccess?.call();

  void _handleLoadError(LynxLoadError error) => onLoadError?.call(error);

  void _handleReceivedError(LynxLoadError error) => onReceivedError?.call(error);

  void _handleMessage(String channel, LynxMessage message) {
    _channels[channel]?.call(message);
  }
}

/// Adapts [LynxViewEventHandler] callbacks to a [LynxViewController]'s
/// private handlers. A separate class (rather than the controller
/// implementing [LynxViewEventHandler] itself) because the controller
/// already exposes public fields named `onLoadSuccess`/`onLoadError` and
/// Dart doesn't allow a field and a method to share a name.
class _LynxViewControllerEventHandler implements LynxViewEventHandler {
  _LynxViewControllerEventHandler(this._controller);

  final LynxViewController _controller;

  @override
  void onLoadSuccess() => _controller._handleLoadSuccess();

  @override
  void onLoadError(LynxLoadError error) => _controller._handleLoadError(error);

  @override
  void onReceivedError(LynxLoadError error) =>
      _controller._handleReceivedError(error);

  @override
  void onMessage(String channel, LynxMessage message) =>
      _controller._handleMessage(channel, message);
}
