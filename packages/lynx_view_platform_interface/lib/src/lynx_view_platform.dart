import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_lynx_view.dart';
import 'types.dart';

/// Callback invoked once the native `LynxView` instance for a
/// [LynxViewPlatform.buildView] call has been created and is ready to
/// receive `reload`/`sendEvent`/`dispose` calls keyed by [viewId].
typedef LynxPlatformViewCreatedCallback = void Function(int viewId);

/// Receives events pushed from the native `LynxView` instance identified by
/// a given `viewId` (load lifecycle + `FlutterBridge` messages).
abstract class LynxViewEventHandler {
  void onLoadSuccess();
  void onLoadError(LynxLoadError error);
  void onMessage(String channel, LynxMessage message);
}

/// The interface implemented by platform-specific `lynx_view` packages
/// (`lynx_view_android`, `lynx_view_ios`). App code should not implement this
/// directly or call it; use the `lynx_view` package's `LynxView` widget and
/// `LynxViewController` instead.
abstract class LynxViewPlatform extends PlatformInterface {
  LynxViewPlatform() : super(token: _token);

  static final Object _token = Object();

  static LynxViewPlatform _instance = MethodChannelLynxView();

  /// The active platform implementation. Defaults to a [MethodChannelLynxView]
  /// instance backed by the platform package registered for the running OS.
  static LynxViewPlatform get instance => _instance;

  static set instance(LynxViewPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Builds the embedded native view for a `LynxView` widget.
  ///
  /// [creationParams] are handed to the native `PlatformViewFactory`
  /// (`templateUrl`, `initData`, JSON-encodable). [onPlatformViewCreated]
  /// fires once the native view exists and [viewId] can be used with
  /// [reload], [sendEvent], [dispose] and [setEventHandler].
  ///
  /// [gestureRecognizers] decides which gestures the embedded native view is
  /// allowed to win from Flutter. Without it the platform view only receives
  /// what no Flutter widget claims — taps get through, but drags do not, so
  /// anything scrollable inside the Lynx template will not scroll.
  Widget buildView({
    required Map<String, dynamic> creationParams,
    required LynxPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  }) {
    throw UnimplementedError('buildView() has not been implemented.');
  }

  /// Registers the handler that receives load lifecycle and bridge-message
  /// events for [viewId]. Replaces any previously registered handler.
  void setEventHandler(int viewId, LynxViewEventHandler handler) {
    throw UnimplementedError('setEventHandler() has not been implemented.');
  }

  /// Loads a new template into the native view identified by [viewId].
  Future<void> reload(
    int viewId, {
    required String templateUrl,
    Map<String, dynamic>? initData,
  }) {
    throw UnimplementedError('reload() has not been implemented.');
  }

  /// Broadcasts a Dart -> JS event via Lynx's `GlobalEventEmitter`.
  Future<void> sendEvent(
    int viewId, {
    required String name,
    required Map<String, dynamic> args,
  }) {
    throw UnimplementedError('sendEvent() has not been implemented.');
  }

  /// Releases the native `LynxView` resources owned by [viewId]. Idempotent.
  Future<void> dispose(int viewId) {
    throw UnimplementedError('dispose() has not been implemented.');
  }
}
