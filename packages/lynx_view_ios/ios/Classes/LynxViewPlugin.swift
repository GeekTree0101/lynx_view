import Foundation
import Lynx

/// Public entry point for apps that need a custom native module reachable
/// from Lynx JS (`NativeModules.YourCustomModule`). Call
/// `registerNativeModule` once at app startup (e.g. `AppDelegate`'s
/// `application(_:didFinishLaunchingWithOptions:)`).
///
/// Lynx only supports registering modules globally against `LynxConfig`
/// (via `LynxEnv.sharedInstance().config`), not per `LynxView` instance —
/// see the design note in the techspec. Since that config is only actually
/// prepared lazily, the first time a `LynxView` is created (see
/// `ensureInitialized`), calls made here are safe regardless of whether
/// that has happened yet: they're queued and flushed at that point.
@objcMembers
public final class LynxViewPlugin: NSObject {
    private static var pendingModules: [(name: String, moduleClass: LynxModule.Type)] = []
    private static var initialized = false
    private static let lock = NSLock()

    public static func registerNativeModule(_ name: String, moduleClass: LynxModule.Type) {
        lock.lock()
        defer { lock.unlock() }
        if initialized {
            LynxEnv.sharedInstance().config.register(moduleClass, withName: name)
        } else {
            pendingModules.append((name, moduleClass))
        }
    }

    public static func unregisterNativeModule(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        pendingModules.removeAll { $0.name == name }
        // TODO(Phase 3 SDK verification): confirm LynxConfig exposes an
        // unregister call for modules registered after prepareConfig; the
        // public headers only show registration, not removal.
    }

    /// Lazily prepares the real Lynx config the first time it's needed (i.e.
    /// right before the first native `LynxView` is created), then flushes any
    /// module registrations queued via `registerNativeModule` up to this
    /// point. Safe to call repeatedly.
    static func ensureInitialized() {
        lock.lock()
        defer { lock.unlock() }
        if initialized { return }

        let config = LynxConfig(provider: RemoteTemplateProvider())
        LynxEnv.sharedInstance().prepareConfig(config)
        config.register(FlutterBridgeModule.self, withName: FlutterBridgeModule.name)
        for pending in pendingModules {
            config.register(pending.moduleClass, withName: pending.name)
        }
        pendingModules.removeAll()
        initialized = true
    }

    /// Test-only: names still queued (i.e. not yet flushed by `ensureInitialized`).
    static func pendingModuleNamesForTesting() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return pendingModules.map { $0.name }
    }

    /// Test-only: resets singleton state between test cases. Never call from app code.
    static func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        pendingModules.removeAll()
        initialized = false
    }
}
