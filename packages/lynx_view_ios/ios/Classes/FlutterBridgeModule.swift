import Foundation
import Lynx

/// Built-in, package-provided native module — the "Tier 1" generic JS <-> Dart
/// pipe described in the techspec (`addJavaScriptChannel`/`sendEvent` on
/// `LynxViewController`, no app-authored native code required). Always
/// registered automatically by `LynxViewPlugin.ensureInitialized`; apps only
/// need `LynxViewPlugin.registerNativeModule` for "Tier 2" custom modules.
///
/// JS side: `NativeModules.FlutterBridge.postMessage(channel, payload)`.
@objcMembers
final class FlutterBridgeModule: NSObject, LynxContextModule {
    static let name: String = "FlutterBridge"
    static let methodLookup: [String: String] = [
        "postMessage": NSStringFromSelector(#selector(postMessage(channel:payload:))),
    ]

    private weak var context: LynxContext?

    required init(lynxContext context: LynxContext) {
        self.context = context
        super.init()
    }

    required init(lynxContext context: LynxContext, withParam param: Any) {
        self.context = context
        super.init()
    }

    // The `LynxModule`/`LynxContextModule` protocols mark these `@optional`
    // in Objective-C, but Swift still requires stub conformances for any
    // initializer they declare (a known ObjC-protocol-in-Swift quirk).
    // FlutterBridgeModule is only ever meant to be constructed via
    // `init(lynxContext:)` — these paths leave `context` nil, so
    // `postMessage` becomes a no-op rather than crashing if the engine ever
    // takes one of these routes instead.
    required override init() {
        self.context = nil
        super.init()
    }

    required init(param: Any) {
        self.context = nil
        super.init()
    }

    @objc func postMessage(channel: String, payload: String) {
        guard let viewId = context?.getLynxView()?.tag,
            let methodChannel = LynxViewRegistry.shared.channel(forViewId: viewId)
        else {
            return
        }
        DispatchQueue.main.async {
            methodChannel.invokeMethod("onMessage", arguments: ["channel": channel, "payload": payload])
        }
    }
}
