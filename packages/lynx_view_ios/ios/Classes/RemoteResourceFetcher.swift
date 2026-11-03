import Foundation
import Lynx

/// The generic resource fetcher Lynx asks for anything that is not an
/// `<image>`: an `<svg src="https://…">`, a font named by URL, a Lottie file.
///
/// Lynx has no built-in loader for these. `<image>` goes through the image
/// service (SDWebImage here), but the rest go through
/// `LynxUIContext.genericResourceFetcher`, and when that is nil XElement's
/// `<svg>` messages nil and draws nothing — no log, no error. This is the
/// default; a host that needs auth headers or its own cache swaps it with
/// `LynxViewPlugin.setResourceFetcher`.
///
/// Plain `GET` over HTTP(S), no headers added, `URLSession.shared`'s default
/// cache behaviour. The template provider forces revalidation because OTA
/// republishes at one URL; resources are addressed by content (a new icon is
/// a new key) and need no such care.
final class RemoteResourceFetcher: NSObject, LynxGenericResourceFetcher {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchResource(
        _ request: LynxResourceRequest,
        onComplete callback: @escaping LynxGenericResourceCompletionBlock
    ) -> () -> Void {
        download(request.url) { data, error in callback(data, error) }
    }

    /// Same bytes, parked in a temp file. Lynx asks for a path rather than
    /// bytes for the few resources it hands to a platform API that wants a
    /// file. The file is never removed; the OS owns the temp directory.
    func fetchResourcePath(
        _ request: LynxResourceRequest,
        onComplete callback: @escaping LynxGenericResourcePathCompletionBlock
    ) -> () -> Void {
        download(request.url) { data, error in
            guard let data else {
                callback(nil, error)
                return
            }
            let file = FileManager.default.temporaryDirectory
                .appendingPathComponent("lynx_resource_\(UUID().uuidString)")
            do {
                try data.write(to: file)
                callback(file.path, nil)
            } catch {
                callback(nil, error as NSError)
            }
        }
    }

    /// Returns the cancel block Lynx's protocol asks for.
    private func download(
        _ url: String,
        completion: @escaping (Data?, NSError?) -> Void
    ) -> () -> Void {
        guard let requestUrl = URL(string: url),
              let scheme = requestUrl.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            completion(nil, Self.error(code: -1, message: "Unsupported resource URL: \(url)"))
            return {}
        }

        let task = session.dataTask(with: URLRequest(url: requestUrl)) { data, response, error in
            if let error {
                completion(nil, error as NSError)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode)
            else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(nil, Self.error(code: status, message: "HTTP \(status) for \(url)"))
                return
            }
            completion(data ?? Data(), nil)
        }
        task.resume()
        return { task.cancel() }
    }

    private static func error(code: Int, message: String) -> NSError {
        NSError(
            domain: "com.geektree0101.lynx_view_ios",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
