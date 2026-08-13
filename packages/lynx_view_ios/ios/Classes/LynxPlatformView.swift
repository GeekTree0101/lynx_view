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
    private let containerView: LynxContainerView
    private let channel: FlutterMethodChannel
    private let viewId: Int64

    /// Lynx cannot cancel a template load, and two loads running at once on
    /// the same `LynxView` race each other into an empty tree. So only one is
    /// ever in flight; a request that arrives during one is remembered and
    /// runs after it, and only the last one is kept — a burst of `reload()`
    /// calls collapses to "load the newest URL", never a pile-up.
    /// Main-thread only.
    private var isLoading = false
    private var pendingLoad: (templateUrl: String, initData: [String: Any]?)?

    init(
        frame: CGRect,
        viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        self.viewId = viewId
        let lynxView = LynxView(frame: frame)
        self.lynxView = lynxView
        self.containerView = LynxContainerView(lynxView: lynxView)
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
        containerView
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
        if isLoading {
            pendingLoad = (templateUrl, initData)
            return
        }
        isLoading = true
        let templateData = LynxTemplateData(dictionary: initData ?? [:])
        lynxView.loadTemplate(fromURL: templateUrl, initData: templateData)
    }

    /// Called when the in-flight load reports back. Returns true if another
    /// request came in while it was running — in that case this load's result
    /// is stale and must not be reported to Dart, since the newer load is
    /// what will actually end up on screen.
    private func finishLoad() -> Bool {
        isLoading = false
        guard let next = pendingLoad else { return false }
        pendingLoad = nil
        load(templateUrl: next.templateUrl, initData: next.initData)
        return true
    }

    /// `FlutterPlatformView` has no teardown hook of its own — unlike Android's
    /// `PlatformView.dispose()`, the engine simply releases this object. So the
    /// only deterministic moment to release Lynx's resources is the Dart
    /// controller's explicit `dispose()`, and `deinit` is the backstop for when
    /// that never comes. Both funnel here, hence the flag.
    private var isDisposed = false

    private func disposeInternal() {
        if isDisposed { return }
        isDisposed = true
        LynxViewRegistry.shared.unregister(viewId: Int(viewId))
        channel.setMethodCallHandler(nil)
        lynxView.removeLifecycleClient(self)
        pendingLoad = nil
        // Releasing the last reference is not enough to reclaim the engine
        // promptly: Lynx holds internal references of its own, and ARC only
        // runs `deinit` once every one of them is gone. `clearForDestroy` is
        // Lynx's own teardown entry point and is what makes release
        // deterministic here, mirroring `destroy()` on Android.
        //
        // The channel path always lands on the platform thread, but `deinit`
        // runs wherever the last release happened — so hop when needed. The
        // local binding (rather than `self`) is what keeps the view alive
        // until the block runs; `self` may already be gone.
        let view = lynxView
        if Thread.isMainThread {
            view.clearForDestroy()
        } else {
            DispatchQueue.main.async { view.clearForDestroy() }
        }
    }

    deinit {
        disposeInternal()
    }
}

extension LynxPlatformView: LynxViewLifecycle {
    // Lynx invokes these lifecycle callbacks off the main thread, but
    // FlutterMethodChannel.invokeMethod must be called on the platform
    // thread — calling it directly here trips the engine's threading
    // check and can corrupt rendering for anything composited after this
    // platform view (see FlutterBridgeModule.postMessage for the same fix).
    func lynxView(_ view: LynxView, didLoadFinishedWithUrl url: String) {
        DispatchQueue.main.async { [self] in
            if finishLoad() { return }
            channel.invokeMethod("onLoadSuccess", arguments: nil)
        }
    }

    func lynxView(_ view: LynxView, didRecieveError error: Error) {
        // Lynx reports every error through this one callback — a template
        // that failed to load, but also an <image> src that 404'd or a
        // runtime warning. Only the fatal ones mean the view is broken;
        // forwarding the rest as "onLoadError" made consumers kill screens
        // over a single missing thumbnail. LynxError knows the difference.
        let fatal = (error as? LynxError)?.isFatal ?? true
        let nsError = error as NSError
        DispatchQueue.main.async { [self] in
            if !fatal {
                channel.invokeMethod(
                    "onReceivedError",
                    arguments: ["code": "\(nsError.code)", "message": nsError.localizedDescription]
                )
                return
            }
            if finishLoad() { return }
            channel.invokeMethod(
                "onLoadError",
                arguments: ["code": "\(nsError.code)", "message": nsError.localizedDescription]
            )
        }
    }
}
