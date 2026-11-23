import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'lynx_view_platform.dart';
import 'types.dart';

const String _kViewType = 'com.geektree0101.lynx_view/LynxView';
const String _kInstanceChannelPrefix = 'com.geektree0101.lynx_view/instance_';

/// Process-wide channel for calls that aren't about one particular view.
/// Answered by the plugin registrant on each platform, not by a platform view.
const MethodChannel _kPluginChannel =
    MethodChannel('com.geektree0101.lynx_view/plugin');

/// Default [LynxViewPlatform] implementation, backed by Flutter's
/// [AndroidView]/[UiKitView] platform views plus a per-instance
/// [MethodChannel] keyed by the platform-assigned `viewId`.
///
/// Shared by both `lynx_view_android` and `lynx_view_ios` — the only
/// platform-specific piece is which native `PlatformViewFactory` answers to
/// [_kViewType] and which native code answers the per-instance channel.
class MethodChannelLynxView extends LynxViewPlatform {
  final Map<int, MethodChannel> _channels = <int, MethodChannel>{};
  final Map<int, LynxViewEventHandler> _handlers = <int, LynxViewEventHandler>{};

  @override
  Widget buildView({
    required Map<String, dynamic> creationParams,
    required LynxPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
    LynxAndroidViewMode androidViewMode = LynxAndroidViewMode.textureLayer,
  }) {
    void onCreated(int viewId) {
      final MethodChannel channel =
          MethodChannel('$_kInstanceChannelPrefix$viewId');
      channel.setMethodCallHandler((call) => _onMethodCall(viewId, call));
      _channels[viewId] = channel;
      onPlatformViewCreated(viewId);
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final Widget textureLayer = AndroidView(
          viewType: _kViewType,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: onCreated,
          gestureRecognizers: gestureRecognizers ?? const {},
        );
        if (androidViewMode != LynxAndroidViewMode.hybridCompositionPlusPlus) {
          return textureLayer;
        }
        return _HcppOrFallback(
          support: this,
          fallback: textureLayer,
          creationParams: creationParams,
          onPlatformViewCreated: onCreated,
          gestureRecognizers: gestureRecognizers ?? const {},
        );
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: _kViewType,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: onCreated,
          gestureRecognizers: gestureRecognizers ?? const {},
        );
      default:
        throw UnsupportedError(
          'lynx_view does not support $defaultTargetPlatform. '
          'Only Android and iOS are supported.',
        );
    }
  }

  Future<bool>? _hcppSupport;

  /// The settled answer of [isAndroidHcppSupported], once there is one — lets
  /// every view after the first build without waiting a frame for it.
  bool? _hcppSupported;

  @override
  Future<bool> isAndroidHcppSupported() => _hcppSupport ??= _checkHcpp();

  Future<bool> _checkHcpp() async {
    bool supported = false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        supported = await HybridAndroidViewController.checkIfSupported();
      } catch (_) {
        // An engine that does not answer cannot do HCPP either.
        supported = false;
      }
    }
    return _hcppSupported = supported;
  }

  @override
  void setEventHandler(int viewId, LynxViewEventHandler handler) {
    _handlers[viewId] = handler;
  }

  Future<dynamic> _onMethodCall(int viewId, MethodCall call) async {
    final LynxViewEventHandler? handler = _handlers[viewId];
    if (handler == null) return null;

    switch (call.method) {
      case 'onLoadSuccess':
        handler.onLoadSuccess();
        return null;
      case 'onLoadError':
        final Map<dynamic, dynamic> args =
            call.arguments as Map<dynamic, dynamic>;
        handler.onLoadError(
          LynxLoadError(
            code: args['code'] as String? ?? 'unknown',
            message: args['message'] as String? ?? '',
          ),
        );
        return null;
      case 'onReceivedError':
        final Map<dynamic, dynamic> args =
            call.arguments as Map<dynamic, dynamic>;
        handler.onReceivedError(
          LynxLoadError(
            code: args['code'] as String? ?? 'unknown',
            message: args['message'] as String? ?? '',
          ),
        );
        return null;
      case 'onMessage':
        final Map<dynamic, dynamic> args =
            call.arguments as Map<dynamic, dynamic>;
        final String channelName = args['channel'] as String;
        handler.onMessage(
          channelName,
          LynxMessage(data: _decodePayload(args['payload'])),
        );
        return null;
      default:
        throw MissingPluginException('Unimplemented method: ${call.method}');
    }
  }

  dynamic _decodePayload(dynamic raw) {
    if (raw is String) {
      try {
        return jsonDecode(raw);
      } catch (_) {
        return raw;
      }
    }
    return raw;
  }

  MethodChannel _requireChannel(int viewId) {
    final MethodChannel? channel = _channels[viewId];
    if (channel == null) {
      throw StateError(
        'No native LynxView is registered for viewId $viewId. '
        'Was it already disposed?',
      );
    }
    return channel;
  }

  @override
  Future<void> reload(
    int viewId, {
    required String templateUrl,
    Map<String, dynamic>? initData,
  }) {
    return _requireChannel(viewId).invokeMethod<void>(
      'reload',
      <String, dynamic>{'templateUrl': templateUrl, 'initData': initData},
    );
  }

  @override
  Future<void> sendEvent(
    int viewId, {
    required String name,
    required Map<String, dynamic> args,
  }) {
    return _requireChannel(viewId).invokeMethod<void>(
      'sendEvent',
      <String, dynamic>{'name': name, 'args': args},
    );
  }

  @override
  Future<void> setVisible(int viewId, {required bool visible}) {
    return _requireChannel(viewId).invokeMethod<void>(
      'setVisible',
      <String, dynamic>{'visible': visible},
    );
  }

  @override
  Future<void> setTouchEnabled(int viewId, {required bool enabled}) {
    return _requireChannel(viewId).invokeMethod<void>(
      'setTouchEnabled',
      <String, dynamic>{'enabled': enabled},
    );
  }

  @override
  Future<void> dispose(int viewId) async {
    final MethodChannel? channel = _channels.remove(viewId);
    _handlers.remove(viewId);
    if (channel == null) return;
    await channel.invokeMethod<void>('dispose');
  }

  @override
  Future<void> trimMemory(LynxMemoryPressureLevel level) {
    return _kPluginChannel.invokeMethod<void>(
      'trimMemory',
      <String, dynamic>{'level': level.value},
    );
  }

  @override
  Future<LynxMemoryUsage> queryMemoryUsage({int? timeoutMs}) async {
    final Map<dynamic, dynamic>? raw =
        await _kPluginChannel.invokeMethod<Map<dynamic, dynamic>>(
      'queryMemoryUsage',
      <String, dynamic>{'timeoutMs': timeoutMs},
    );
    if (raw == null) {
      throw StateError('queryMemoryUsage returned no result');
    }
    return _decodeUsage(raw);
  }

  LynxMemoryUsage _decodeUsage(Map<dynamic, dynamic> m) {
    final List<dynamic> rawInstances =
        (m['instances'] as List<dynamic>?) ?? const <dynamic>[];
    return LynxMemoryUsage(
      totalBytes: _int(m['totalBytes']),
      appBytes: _int(m['appBytes']),
      ratioToApp: (m['ratioToApp'] as num?)?.toDouble() ?? 0,
      elementBytes: _int(m['elementBytes']),
      elementNodeCount: _int(m['elementNodeCount']),
      viewBytes: _int(m['viewBytes']),
      mainThreadRuntimeBytes: _int(m['mainThreadRuntimeBytes']),
      backgroundThreadRuntimeBytes: _int(m['backgroundThreadRuntimeBytes']),
      expectedInstanceCount: _int(m['expectedInstanceCount']),
      completedInstanceCount: _int(m['completedInstanceCount']),
      timedOut: m['timedOut'] == true,
      instances: rawInstances
          .cast<Map<dynamic, dynamic>>()
          .map(_decodeInstance)
          .toList(growable: false),
    );
  }

  LynxInstanceMemory _decodeInstance(Map<dynamic, dynamic> m) {
    return LynxInstanceMemory(
      instanceId: _int(m['instanceId']),
      url: m['url'] as String?,
      totalBytes: _int(m['totalBytes']),
      elementBytes: _int(m['elementBytes']),
      elementNodeCount: _int(m['elementNodeCount']),
      viewBytes: _int(m['viewBytes']),
      mainThreadRuntimeBytes: _int(m['mainThreadRuntimeBytes']),
      backgroundThreadRuntimeBytes: _int(m['backgroundThreadRuntimeBytes']),
      backgroundRuntimeGroupId: m['backgroundRuntimeGroupId'] as String?,
    );
  }

  /// Byte counts cross the channel as `int` on one platform and `long` on the
  /// other; both arrive as `num` here.
  int _int(dynamic value) => (value as num?)?.toInt() ?? 0;
}

/// Builds the native view with Hybrid Composition++ where the engine can do
/// it, and with [fallback] (the plain texture-layer `AndroidView`) where it
/// cannot.
///
/// Asking the engine for an HCPP view it cannot make is an error, not a
/// downgrade, so the question has to be settled first. It is one channel
/// round trip, asked once per process: only the very first view waits for
/// it, and holds an empty box rather than building the fallback — building
/// it and then swapping would create the native view twice.
class _HcppOrFallback extends StatefulWidget {
  const _HcppOrFallback({
    required this.support,
    required this.fallback,
    required this.creationParams,
    required this.onPlatformViewCreated,
    required this.gestureRecognizers,
  });

  final MethodChannelLynxView support;
  final Widget fallback;
  final Map<String, dynamic> creationParams;
  final PlatformViewCreatedCallback onPlatformViewCreated;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  @override
  State<_HcppOrFallback> createState() => _HcppOrFallbackState();
}

class _HcppOrFallbackState extends State<_HcppOrFallback> {
  bool? _supported;

  @override
  void initState() {
    super.initState();
    _supported = widget.support._hcppSupported;
    if (_supported == null) {
      widget.support.isAndroidHcppSupported().then((bool supported) {
        if (mounted) setState(() => _supported = supported);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool? supported = _supported;
    if (supported == null) return const SizedBox.expand();
    if (!supported) return widget.fallback;

    final TextDirection layoutDirection =
        Directionality.maybeOf(context) ?? TextDirection.ltr;
    return PlatformViewLink(
      viewType: _kViewType,
      surfaceFactory: (BuildContext context, PlatformViewController controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: widget.gestureRecognizers,
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (PlatformViewCreationParams params) {
        return PlatformViewsService.initHybridAndroidView(
            id: params.id,
            viewType: _kViewType,
            layoutDirection: layoutDirection,
            creationParams: widget.creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () => params.onFocusChanged(true),
          )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..addOnPlatformViewCreatedListener(widget.onPlatformViewCreated)
          ..create();
      },
    );
  }
}
