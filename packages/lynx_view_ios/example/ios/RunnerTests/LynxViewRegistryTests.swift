import Flutter
import XCTest

@testable import lynx_view_ios

private final class FakeBinaryMessenger: NSObject, FlutterBinaryMessenger {
    func send(onChannel channel: String, message: Data?) {}

    func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {}

    func setMessageHandlerOnChannel(
        _ channel: String,
        binaryMessageHandler handler: FlutterBinaryMessageHandler?
    ) -> FlutterBinaryMessengerConnection {
        0
    }

    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}

final class LynxViewRegistryTests: XCTestCase {
    private var registeredIds: [Int] = []

    private func fakeChannel() -> FlutterMethodChannel {
        FlutterMethodChannel(name: "test", binaryMessenger: FakeBinaryMessenger())
    }

    override func tearDown() {
        registeredIds.forEach { LynxViewRegistry.shared.unregister(viewId: $0) }
        registeredIds.removeAll()
        super.tearDown()
    }

    func testChannelForReturnsNilWhenNothingRegistered() {
        XCTAssertNil(LynxViewRegistry.shared.channel(forViewId: 999_001))
    }

    func testRegisterThenChannelForReturnsTheSameChannelInstance() {
        let channel = fakeChannel()
        LynxViewRegistry.shared.register(viewId: 999_002, channel: channel)
        registeredIds.append(999_002)

        XCTAssertTrue(LynxViewRegistry.shared.channel(forViewId: 999_002) === channel)
    }

    func testUnregisterRemovesTheMapping() {
        let channel = fakeChannel()
        LynxViewRegistry.shared.register(viewId: 999_003, channel: channel)

        LynxViewRegistry.shared.unregister(viewId: 999_003)

        XCTAssertNil(LynxViewRegistry.shared.channel(forViewId: 999_003))
    }

    func testRegisteringANewChannelForTheSameViewIdReplacesTheOldOne() {
        let first = fakeChannel()
        let second = fakeChannel()
        LynxViewRegistry.shared.register(viewId: 999_004, channel: first)
        LynxViewRegistry.shared.register(viewId: 999_004, channel: second)
        registeredIds.append(999_004)

        XCTAssertTrue(LynxViewRegistry.shared.channel(forViewId: 999_004) === second)
    }
}
