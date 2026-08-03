import Flutter
import UIKit

/// Registers the `LynxView` platform view factory. All actual Lynx
/// initialization is deferred to `LynxViewPlugin.ensureInitialized`, the
/// first time a `LynxView` is created — see that class for why.
public class LynxViewIosPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let factory = LynxPlatformViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: lynxViewType)
    }
}
