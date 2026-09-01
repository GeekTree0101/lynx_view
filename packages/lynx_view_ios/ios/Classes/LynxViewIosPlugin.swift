import Flutter
import Lynx
import UIKit

/// Channel for calls that aren't about one particular view.
private let pluginChannelName = "com.geektree0101.lynx_view/plugin"

/// Registers the `LynxView` platform view factory and the process-wide plugin
/// channel. All actual Lynx initialization is deferred to
/// `LynxViewPlugin.ensureInitialized`, the first time a `LynxView` is created —
/// see that class for why.
public class LynxViewIosPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let factory = LynxPlatformViewFactory(messenger: registrar.messenger())
        // Lynx recognizes taps with its own native UITapGestureRecognizer, and
        // the default Eager policy only guarantees delivery of touchesBegan to
        // a platform view's recognizers — the rest of a sequence may be cut
        // mid-stream whenever Flutter blocks, which surfaced as intermittent
        // lost taps on iOS. WaitUntilTouchesEnded defers that block to the end
        // of the sequence, so Lynx always sees begin/move/end as a whole.
        registrar.register(
            factory,
            withId: lynxViewType,
            gestureRecognizersBlockingPolicy: FlutterPlatformViewGestureRecognizersBlockingPolicyWaitUntilTouchesEnded
        )

        let channel = FlutterMethodChannel(
            name: pluginChannelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(LynxViewIosPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "trimMemory":
            guard let args = call.arguments as? [String: Any],
                let raw = args["level"] as? Int,
                let level = LynxMemoryPressureLevel(rawValue: raw)
            else {
                result(FlutterError(
                    code: "invalid_args",
                    message: "level must be a valid LynxMemoryPressureLevel",
                    details: nil
                ))
                return
            }
            LynxEnv.sharedInstance().trimMemory(level)
            result(nil)
        case "queryMemoryUsage":
            let timeoutMs = ((call.arguments as? [String: Any])?["timeoutMs"] as? NSNumber)?.int64Value ?? 0
            LynxMemoryUsageQuery.sharedInstance().queryLynxGlobalMemoryUsageAsync({ usage in
                // Lynx answers on its own report thread; FlutterResult must be
                // delivered on the platform thread.
                DispatchQueue.main.async { result(Self.encode(usage)) }
            }, timeoutMs: timeoutMs)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static func encode(_ usage: LynxGlobalMemoryUsageResult) -> [String: Any] {
        return [
            "totalBytes": usage.totalBytes,
            "appBytes": usage.appBytes,
            "ratioToApp": usage.ratioToApp,
            "elementBytes": usage.elementBytes,
            "elementNodeCount": usage.elementNodeCount,
            "viewBytes": usage.viewBytes,
            "mainThreadRuntimeBytes": usage.mainThreadRuntimeBytes,
            "backgroundThreadRuntimeBytes": usage.backgroundThreadRuntimeBytes,
            "expectedInstanceCount": usage.expectedInstanceCount,
            "completedInstanceCount": usage.completedInstanceCount,
            "timedOut": usage.collectionStatus == .timeout,
            "instances": usage.instances.map(encodeInstance),
        ]
    }

    private static func encodeInstance(_ instance: LynxInstanceMemoryUsage) -> [String: Any] {
        return [
            "instanceId": instance.instanceId,
            "url": instance.url,
            "totalBytes": instance.totalBytes,
            "elementBytes": instance.elementBytes,
            "elementNodeCount": instance.elementNodeCount,
            "viewBytes": instance.viewBytes,
            "mainThreadRuntimeBytes": instance.mainThreadRuntimeBytes,
            "backgroundThreadRuntimeBytes": instance.backgroundThreadRuntimeBytes,
            "backgroundRuntimeGroupId": instance.btsRuntimeGroupId,
        ]
    }
}
