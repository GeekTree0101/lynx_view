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

/// How much memory Lynx should hand back when the platform reports pressure.
///
/// The raw [value]s are Lynx's own — `LynxMemoryPressureLevel` on iOS and
/// `MemoryPressureLevel` on Android use the same numbering — so the level
/// passes straight through to `LynxEnv.trimMemory` without translation.
///
/// Lynx also defines a `none` (0) level, but it is never dispatched as a
/// signal, so it is deliberately not offered here.
enum LynxMemoryPressureLevel {
  /// Release buffers that are cheap to rebuild and not needed right now.
  moderate(1),

  /// Release everything possible. The alternative is being killed by the
  /// system, which costs the whole cold start to recover.
  critical(2);

  const LynxMemoryPressureLevel(this.value);

  /// The integer Lynx's native API expects.
  final int value;
}

/// What one live Lynx instance is holding, in bytes.
///
/// Lynx samples heap stats without forcing a GC, so treat these as a snapshot
/// rather than a settled figure.
class LynxInstanceMemory {
  const LynxInstanceMemory({
    required this.instanceId,
    required this.url,
    required this.totalBytes,
    required this.elementBytes,
    required this.elementNodeCount,
    required this.viewBytes,
    required this.mainThreadRuntimeBytes,
    required this.backgroundThreadRuntimeBytes,
    required this.backgroundRuntimeGroupId,
  });

  final int instanceId;

  /// The template this instance rendered, when Lynx reports one.
  final String? url;

  final int totalBytes;

  /// The element tree.
  final int elementBytes;
  final int elementNodeCount;

  /// The platform UI objects Lynx created (Android `View`s / `UIView`s).
  final int viewBytes;

  /// Main-thread runtime heap (PrimJS).
  final int mainThreadRuntimeBytes;

  /// Background-thread runtime heap — PrimJS on Android, JavaScriptCore on iOS.
  final int backgroundThreadRuntimeBytes;

  /// Which background runtime this instance shares, if any. Instances with the
  /// same non-empty id count their background heap only once in
  /// [LynxMemoryUsage.backgroundThreadRuntimeBytes] — which is exactly how much
  /// grouping instances would save.
  final String? backgroundRuntimeGroupId;

  @override
  String toString() => 'LynxInstanceMemory(id: $instanceId, total: $totalBytes)';
}

/// A process-wide snapshot of what Lynx is holding, and how that compares to
/// the app's own footprint.
class LynxMemoryUsage {
  const LynxMemoryUsage({
    required this.totalBytes,
    required this.appBytes,
    required this.ratioToApp,
    required this.elementBytes,
    required this.elementNodeCount,
    required this.viewBytes,
    required this.mainThreadRuntimeBytes,
    required this.backgroundThreadRuntimeBytes,
    required this.expectedInstanceCount,
    required this.completedInstanceCount,
    required this.timedOut,
    required this.instances,
  });

  /// Everything Lynx accounts for, with shared background runtimes counted once.
  final int totalBytes;

  /// The app's physical footprint when this snapshot was built — the figure the
  /// OS actually holds the app to, which is not the same as RSS.
  final int appBytes;

  /// [totalBytes] / [appBytes]. Zero when the footprint was unavailable.
  final double ratioToApp;

  final int elementBytes;
  final int elementNodeCount;
  final int viewBytes;
  final int mainThreadRuntimeBytes;

  /// Aggregated background runtime bytes, deduplicated across shared groups.
  final int backgroundThreadRuntimeBytes;

  /// How many instances were live when the query started.
  final int expectedInstanceCount;

  /// How many of those answered in time. Fewer than expected means the numbers
  /// below are partial.
  final int completedInstanceCount;

  /// Whether collection hit its timeout and returned a partial result.
  final bool timedOut;

  /// Per-instance detail, largest first.
  final List<LynxInstanceMemory> instances;

  @override
  String toString() => 'LynxMemoryUsage(lynx: $totalBytes, app: $appBytes, '
      'instances: $completedInstanceCount/$expectedInstanceCount)';
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

/// A font file the host app ships as a Flutter asset, handed to Lynx so
/// templates can select it by name.
///
/// Lynx resolves `font-family` by name and nothing else. It has no way to
/// choose between several weights registered under one name — on Android
/// every CSS weight from 500 up collapses into a single "bold" slot, and
/// `@font-face` is keyed by family on both platforms. So one entry here is
/// one weight of one typeface: register `Pretendard-Regular` and
/// `Pretendard-Bold` under two [family] names and let the template pick
/// between them with `font-family`, not `font-weight`.
class LynxFontAsset {
  const LynxFontAsset({required this.family, required this.assetPath});

  /// The name templates ask for — `font-family: <family>` in CSS.
  final String family;

  /// A Flutter asset key, exactly as the host app's `pubspec.yaml` spells it
  /// (e.g. `assets/fonts/Pretendard-Regular.otf`). Files declared under
  /// `fonts:` are in the asset bundle too, so a typeface the Flutter side
  /// already draws with does not need a second copy for Lynx.
  final String assetPath;

  Map<String, Object?> toMap() => <String, Object?>{
        'family': family,
        'assetPath': assetPath,
      };

  @override
  String toString() => 'LynxFontAsset(family: $family, assetPath: $assetPath)';
}
