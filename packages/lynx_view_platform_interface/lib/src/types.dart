/// An error reported while loading a Lynx template bundle.
class LynxLoadError {
  const LynxLoadError({required this.code, required this.message});

  /// A short, platform-defined error code (e.g. `network_error`, `decode_error`).
  final String code;

  /// A human-readable description of the failure.
  final String message;

  @override
  String toString() => 'LynxLoadError(code: $code, message: $message)';
}

/// A message delivered through the built-in `FlutterBridge` channel
/// (JS -> Dart) or via [LynxViewPlatform.sendEvent] (Dart -> JS).
class LynxMessage {
  const LynxMessage({required this.data});

  /// The JSON-decoded payload (`Map`, `List`, `String`, `num`, `bool`, or `null`).
  final dynamic data;

  @override
  String toString() => 'LynxMessage(data: $data)';
}
