import Lynx
import XCTest

@testable import lynx_view_ios

// Covers the pre-init pending-module queue only — never calls
// `LynxViewPlugin.ensureInitialized()`, which requires the real Lynx native
// engine (only meaningfully exercised on-device/simulator at runtime, not a
// plain XCTest unit test).

private final class DummyModule: NSObject, LynxModule {
    static let name = "Dummy"
    static let methodLookup: [String: String] = [:]

    override init() {
        super.init()
    }

    init(param: Any) {
        super.init()
    }
}

private final class OtherDummyModule: NSObject, LynxModule {
    static let name = "Other"
    static let methodLookup: [String: String] = [:]

    override init() {
        super.init()
    }

    init(param: Any) {
        super.init()
    }
}

final class LynxViewPluginTests: XCTestCase {
    override func setUp() {
        super.setUp()
        LynxViewPlugin.resetForTesting()
    }

    override func tearDown() {
        LynxViewPlugin.resetForTesting()
        super.tearDown()
    }

    func testRegisterNativeModuleQueuesBeforeEnsureInitialized() {
        LynxViewPlugin.registerNativeModule("Dummy", moduleClass: DummyModule.self)

        XCTAssertEqual(LynxViewPlugin.pendingModuleNamesForTesting(), ["Dummy"])
    }

    func testMultipleRegistrationsQueueInCallOrder() {
        LynxViewPlugin.registerNativeModule("A", moduleClass: DummyModule.self)
        LynxViewPlugin.registerNativeModule("B", moduleClass: OtherDummyModule.self)

        XCTAssertEqual(LynxViewPlugin.pendingModuleNamesForTesting(), ["A", "B"])
    }

    func testUnregisterNativeModuleRemovesAPendingRegistration() {
        LynxViewPlugin.registerNativeModule("Dummy", moduleClass: DummyModule.self)
        LynxViewPlugin.registerNativeModule("Other", moduleClass: OtherDummyModule.self)

        LynxViewPlugin.unregisterNativeModule("Dummy")

        XCTAssertEqual(LynxViewPlugin.pendingModuleNamesForTesting(), ["Other"])
    }

    func testUnregisterNativeModuleForUnknownNameIsNoOp() {
        LynxViewPlugin.registerNativeModule("Dummy", moduleClass: DummyModule.self)

        LynxViewPlugin.unregisterNativeModule("DoesNotExist")

        XCTAssertEqual(LynxViewPlugin.pendingModuleNamesForTesting(), ["Dummy"])
    }
}
