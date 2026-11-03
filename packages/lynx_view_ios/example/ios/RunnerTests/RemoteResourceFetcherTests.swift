import Lynx
import XCTest

@testable import lynx_view_ios

/// Runs the fetcher against a `URLProtocol` stub, so nothing leaves the
/// process: the session the fetcher is given routes every request here.
private final class StubURLProtocol: URLProtocol {
    static let svg = Data("<svg xmlns=\"http://www.w3.org/2000/svg\"/>".utf8)

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let url = request.url!
        let status = url.path == "/icon.svg" ? 200 : 404
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if status == 200 {
            client?.urlProtocol(self, didLoad: Self.svg)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class RemoteResourceFetcherTests: XCTestCase {
    private var fetcher: RemoteResourceFetcher!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        fetcher = RemoteResourceFetcher(session: URLSession(configuration: configuration))
    }

    private func fetch(_ url: String) -> (Data?, NSError?) {
        let done = expectation(description: "callback")
        var result: (Data?, NSError?) = (nil, nil)
        _ = fetcher.fetchResource(LynxResourceRequest(url: url)) { data, error in
            result = (data, error as NSError?)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return result
    }

    func testFetchResourceReturnsTheBytesOfA2xxResponse() {
        let (data, error) = fetch("https://example.test/icon.svg")

        XCTAssertNil(error)
        XCTAssertEqual(data, StubURLProtocol.svg)
    }

    func testFetchResourceFailsOnANon2xxStatus() {
        let (data, error) = fetch("https://example.test/missing.svg")

        XCTAssertNil(data)
        XCTAssertEqual(error?.code, 404)
    }

    func testFetchResourceFailsOnASchemeItDoesNotServe() {
        let (data, error) = fetch("file:///etc/hosts")

        XCTAssertNil(data)
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.localizedDescription.contains("file:///etc/hosts"))
    }

    func testFetchResourcePathWritesTheBytesToAFileAndReturnsItsPath() {
        let done = expectation(description: "callback")
        var result: (String?, NSError?) = (nil, nil)
        _ = fetcher.fetchResourcePath(LynxResourceRequest(url: "https://example.test/icon.svg")) { path, error in
            result = (path, error as NSError?)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertNil(result.1)
        let path = try! XCTUnwrap(result.0)
        defer { try? FileManager.default.removeItem(atPath: path) }
        XCTAssertEqual(FileManager.default.contents(atPath: path), StubURLProtocol.svg)
    }
}
