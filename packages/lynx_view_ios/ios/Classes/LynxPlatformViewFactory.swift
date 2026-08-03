import Flutter
import Foundation

/// viewType this factory answers to — must match the Dart-side platform interface.
let lynxViewType = "com.geektree0101.lynx_view/LynxView"

final class LynxPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        LynxViewPlugin.ensureInitialized()
        return LynxPlatformView(frame: frame, viewId: viewId, arguments: args, binaryMessenger: messenger)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
