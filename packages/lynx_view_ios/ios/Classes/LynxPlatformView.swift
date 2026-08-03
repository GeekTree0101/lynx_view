import Flutter
import Lynx
import UIKit

private let instanceChannelPrefix = "com.geektree0101.lynx_view/instance_"

/// Wraps one native `LynxView` as a Flutter `FlutterPlatformView`.
///
/// Owns the per-instance `FlutterMethodChannel` that `lynx_view`'s
/// `LynxViewController` talks to: `reload`/`sendEvent`/`dispose` in, and
/// `onLoadSuccess`/`onLoadError`/`onMessage` out.
final class LynxPlatformView: NSObject, FlutterPlatformView {
    private let lynxView: LynxView
    private let channel: FlutterMethodChannel
    private let viewId: Int64

    init(
        frame: CGRect,
        viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        self.viewId = viewId
        self.lynxView = LynxView(frame: frame)
        self.channel = FlutterMethodChannel(
            name: "\(instanceChannelPrefix)\(viewId)",
            binaryMessenger: messenger
        )
        super.init()

        // Lets FlutterBridgeModule (constructed per-LynxView by the engine)
        // find its way back to this view's Dart channel.
        lynxView.tag = Int(viewId)
        LynxViewRegistry.shared.register(viewId: Int(viewId), channel: channel)
        lynxView.addLifecycleClient(self)

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        if let params = args as? [String: Any], let templateUrl = params["templateUrl"] as? String {
            let initData = params["initData"] as? [String: Any]
            load(templateUrl: templateUrl, initData: initData)
        }
    }

    func view() -> UIView {
        lynxView
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "reload":
            guard let args = call.arguments as? [String: Any],
                let templateUrl = args["templateUrl"] as? String
            else {
                result(FlutterError(code: "invalid_args", message: "templateUrl is required", details: nil))
                return
            }
            load(templateUrl: templateUrl, initData: args["initData"] as? [String: Any])
            result(nil)
        case "sendEvent":
            guard let args = call.arguments as? [String: Any], let name = args["name"] as? String else {
                result(FlutterError(code: "invalid_args", message: "name is required", details: nil))
                return
            }
            let params = args["args"] as? [String: Any] ?? [:]
            // Mirrors the public-docs Objective-C sample
            // `[LynxView sendGlobalEvent:withParams:]` — a JS listener
            // receives this as an array of positional params, so we send a
            // 1-element array containing the args map.
            lynxView.sendGlobalEvent(name, withParams: [params])
            result(nil)
        case "dispose":
            disposeInternal()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func load(templateUrl: String, initData: [String: Any]?) {
        let templateData = LynxTemplateData(dictionary: initData ?? [:])
        lynxView.loadTemplate(fromURL: templateUrl, initData: templateData)
    }

    private func disposeInternal() {
        LynxViewRegistry.shared.unregister(viewId: Int(viewId))
        channel.setMethodCallHandler(nil)
        lynxView.removeLifecycleClient(self)
    }

    deinit {
        disposeInternal()
    }
}

extension LynxPlatformView: LynxViewLifecycle {
    func lynxView(_ view: LynxView, didLoadFinishedWithUrl url: String) {
        channel.invokeMethod("onLoadSuccess", arguments: nil)
    }

    func lynxView(_ view: LynxView, didRecieveError error: Error) {
        let nsError = error as NSError
        channel.invokeMethod(
            "onLoadError",
            arguments: ["code": "\(nsError.code)", "message": nsError.localizedDescription]
        )
    }
}
