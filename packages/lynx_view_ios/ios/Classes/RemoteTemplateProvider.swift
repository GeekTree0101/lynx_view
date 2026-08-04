import Foundation
import Lynx

/// Fetches a Lynx template bundle from a remote HTTP(S) URL — this package's
/// v1 loading strategy is "remote only" per the techspec (no bundled asset
/// loading, no on-disk caching between loads).
///
/// No custom-header support yet (v1 signature has none — see the techspec's
/// still-open S3-access-method question); revisit if/when that's decided.
final class RemoteTemplateProvider: NSObject, LynxTemplateProvider {
    func loadTemplate(withUrl url: String, onComplete callback: @escaping LynxTemplateLoadBlock) {
        guard let requestUrl = URL(string: url) else {
            callback(nil, NSError(
                domain: "com.geektree0101.lynx_view_ios",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid template URL: \(url)"]
            ))
            return
        }

        // OTA republishes a new bundle at the *same* URL, so the default cache
        // policy silently defeats `reload()` — iOS keeps serving the copy it
        // already has (across app launches too, since URLCache is on disk) and
        // never even asks the server. Always revalidate: a 304 still lets
        // URLSession hand back the cached bytes, so this costs a conditional
        // request, not a re-download.
        var request = URLRequest(url: requestUrl)
        request.cachePolicy = .reloadRevalidatingCacheData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                callback(nil, error as NSError)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                callback(nil, NSError(
                    domain: "com.geektree0101.lynx_view_ios",
                    code: status,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(status) for \(url)"]
                ))
                return
            }
            callback(data, nil)
        }
        task.resume()
    }
}
