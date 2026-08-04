import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:lynx_view_platform_interface/lynx_view_platform_interface.dart';

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
class LynxView extends StatefulWidget {
  const LynxView({
    super.key,
    required this.controller,
    this.gestureRecognizers,
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

  @override
  State<LynxView> createState() => _LynxViewState();
}

class _LynxViewState extends State<LynxView> {
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
    );
  }
}
