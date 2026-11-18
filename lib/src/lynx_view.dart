import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:lynx_view_platform_interface/lynx_view_platform_interface.dart';

import 'lynx_memory.dart';
import 'lynx_view_controller.dart';

/// Embeds LynxJS (https://lynxjs.org) as a native platform view.
///
/// A [LynxViewController] must be created and owned by the caller (typically
/// via `late final` in a `State`) and passed in here — see
/// [LynxViewController] for the full API (reload, JS bridge, disposal).
///
/// Sizing follows normal Flutter platform-view rules: this widget has no
/// intrinsic size, so wrap it in something that constrains it
/// (`SizedBox`, `Expanded`, `AspectRatio`, ...).
///
/// That size is also what the template load waits for. A template resolves
/// `%`, `flex` and `vh` against the viewport it has while laying out and does
/// not redo that afterwards, so the native view holds its first load until
/// this widget has been given a real size — about a frame, in exchange for a
/// first paint that is already correct. A [LynxView] that never gets a size
/// never loads its bundle.
class LynxView extends StatefulWidget {
  const LynxView({
    super.key,
    required this.controller,
    this.gestureRecognizers,
    this.androidViewMode = LynxAndroidViewMode.textureLayer,
  });

  final LynxViewController controller;

  /// Gestures the embedded native view is allowed to win from Flutter.
  ///
  /// Leave this null and the native view only gets what no Flutter widget
  /// claims: taps arrive, drags do not. A template that scrolls its own
  /// content needs at least a drag recognizer here, e.g.
  ///
  /// ```dart
  /// gestureRecognizers: {
  ///   Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
  /// },
  /// ```
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  /// How Android embeds the native view. iOS ignores this.
  ///
  /// The default, [LynxAndroidViewMode.textureLayer], is what this package has
  /// always done. [LynxAndroidViewMode.hybridCompositionPlusPlus] asks for
  /// Hybrid Composition++ and quietly falls back to the default wherever the
  /// device or the app build cannot do it — check with
  /// [isAndroidHcppSupported]. It needs an opt-in in `AndroidManifest.xml`
  /// that affects the app's other platform views; see the README.
  ///
  /// Decided when the view is created. Changing it on a live [LynxView]
  /// throws the native view away and builds another one.
  final LynxAndroidViewMode androidViewMode;

  /// Whether [LynxAndroidViewMode.hybridCompositionPlusPlus] takes effect on
  /// this device and app build. `false` on iOS, on Android below 14, without
  /// Impeller on Vulkan, and when the app has not opted in.
  static Future<bool> isAndroidHcppSupported() =>
      LynxViewPlatform.instance.isAndroidHcppSupported();

  @override
  State<LynxView> createState() => _LynxViewState();
}

class _LynxViewState extends State<LynxView> {
  @override
  void initState() {
    super.initState();
    // Only worth listening while a native view actually exists — see
    // [LynxMemoryPressureRelay].
    LynxMemoryPressureRelay.retain();
  }

  @override
  void dispose() {
    LynxMemoryPressureRelay.release();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LynxView oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      identical(widget.controller, oldWidget.controller),
      'LynxView does not support swapping controllers on an already-built '
      'element. Use a new LynxView (e.g. give it a new Key) instead.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return LynxViewPlatform.instance.buildView(
      creationParams: widget.controller.creationParams,
      onPlatformViewCreated: widget.controller.attach,
      gestureRecognizers: widget.gestureRecognizers,
      androidViewMode: widget.androidViewMode,
    );
  }
}
