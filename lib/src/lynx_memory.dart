import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lynx_view_platform_interface/lynx_view_platform_interface.dart';

/// Relays the platform's memory-pressure signal to Lynx.
///
/// Flutter already surfaces `applicationDidReceiveMemoryWarning` (iOS) and
/// `onTrimMemory` (Android) as [WidgetsBindingObserver.didHaveMemoryPressure],
/// but nothing forwarded it to Lynx — so a live `LynxView` held on to its
/// caches right up to the moment the system killed the app. Keeping views
/// alive instead of destroying them (which costs a reload and loses scroll
/// position) only works if they can be asked to shed weight under pressure,
/// and this is that hook.
///
/// The relay installs itself while at least one [LynxView] is mounted and
/// removes itself when the last one goes, so an app that never shows a
/// `LynxView` pays nothing.
class LynxMemory {
  LynxMemory._();

  /// Asks every live Lynx instance in this process to release memory now.
  ///
  /// Rarely needed directly — the relay already forwards the platform's own
  /// warnings. Useful for testing the effect, or for shedding weight ahead of
  /// a known-heavy operation.
  static Future<void> trim(LynxMemoryPressureLevel level) =>
      LynxViewPlatform.instance.trimMemory(level);

  /// Asks Lynx what it is currently holding, broken down per live instance.
  ///
  /// Useful for answering "where does a LynxView's memory actually go" without
  /// guessing: the result separates the element tree, the platform views, and
  /// each JS runtime, and reports the app's own physical footprint alongside so
  /// the share is directly comparable.
  ///
  /// Collection is bounded — pass [timeoutMs] to override Lynx's 2000ms
  /// default. A partial result is still returned, flagged as
  /// [LynxMemoryUsage.timedOut].
  static Future<LynxMemoryUsage> usage({int? timeoutMs}) =>
      LynxViewPlatform.instance.queryMemoryUsage(timeoutMs: timeoutMs);
}

/// Bridges [WidgetsBindingObserver.didHaveMemoryPressure] to [LynxMemory.trim].
///
/// Internal — [LynxView] retains and releases it around its own lifetime.
class LynxMemoryPressureRelay extends WidgetsBindingObserver {
  LynxMemoryPressureRelay._();

  static LynxMemoryPressureRelay? _installed;
  static int _refCount = 0;

  /// Installs the observer if this is the first live view.
  static void retain() {
    _refCount++;
    if (_installed != null) return;
    final LynxMemoryPressureRelay relay = LynxMemoryPressureRelay._();
    WidgetsBinding.instance.addObserver(relay);
    _installed = relay;
  }

  /// Removes the observer once the last live view is gone.
  static void release() {
    if (_refCount > 0) _refCount--;
    if (_refCount > 0) return;
    final LynxMemoryPressureRelay? relay = _installed;
    if (relay == null) return;
    WidgetsBinding.instance.removeObserver(relay);
    _installed = null;
  }

  /// Test-only: how many live views are currently holding the relay.
  @visibleForTesting
  static int get refCountForTesting => _refCount;

  /// Test-only: whether the observer is currently registered.
  @visibleForTesting
  static bool get isInstalledForTesting => _installed != null;

  @override
  void didHaveMemoryPressure() {
    // The platform only raises this when it is already short on memory, so
    // there is nothing to gain from asking for a gentler cleanup.
    unawaited(LynxMemory.trim(LynxMemoryPressureLevel.critical));
  }
}
