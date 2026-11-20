import 'package:lynx_view_platform_interface/lynx_view_platform_interface.dart';

/// Process-wide switches for how `<image>` loads.
class LynxImageLoading {
  LynxImageLoading._();

  /// Lets an `<image>` request stop once the `<image>` moves on — a recycled
  /// list cell gets a new `src`, the same `src` is asked for again, the
  /// element goes away.
  ///
  /// Lynx asks the image service to cancel at those moments, but the stock
  /// services in Lynx 4.0.0 cannot: iOS hands back a cancel block aimed at a
  /// request it never stored, and Android never keeps the Fresco
  /// `DataSource` it subscribes to. In a long image list every cell flung
  /// past keeps downloading and decoding behind the ones on screen. With
  /// this on, the plugin keeps each request and cancels it when Lynx says so.
  ///
  /// Off by default. Read per request, so it can follow a remote flag: turn
  /// it on or off at any time and the next request follows.
  static Future<void> setRequestCancellation(bool enabled) =>
      LynxViewPlatform.instance.setImageRequestCancellation(enabled: enabled);
}
