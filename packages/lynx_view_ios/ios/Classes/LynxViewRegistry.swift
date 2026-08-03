import Flutter
import Foundation

/// Maps a Flutter-assigned `viewId` to the per-instance `FlutterMethodChannel`
/// used to talk to that view's Dart-side `LynxViewController`.
///
/// `FlutterBridgeModule` instances are constructed by the Lynx engine per
/// `LynxView` (not globally, despite modules being *registered* globally —
/// see the techspec's Native Module design note), and use this registry to
/// find their way back to the right Dart channel given the `LynxView`
/// they're attached to.
final class LynxViewRegistry {
    static let shared = LynxViewRegistry()

    private var channels: [Int: FlutterMethodChannel] = [:]

    private init() {}

    func register(viewId: Int, channel: FlutterMethodChannel) {
        channels[viewId] = channel
    }

    func unregister(viewId: Int) {
        channels.removeValue(forKey: viewId)
    }

    func channel(forViewId viewId: Int) -> FlutterMethodChannel? {
        channels[viewId]
    }
}
