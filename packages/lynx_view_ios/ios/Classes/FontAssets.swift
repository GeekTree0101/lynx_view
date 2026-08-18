import CoreText
import Flutter
import Foundation
import Lynx
import UIKit

/// Hands host-supplied font files to Lynx, so a template can select them with
/// `font-family`.
///
/// Lynx never loads a font by itself. `@font-face src: url()` is delegated to a
/// resource fetcher this package does not ship, so a template naming a font
/// nobody registered silently draws in the system font. Registering the file
/// the host app already ships skips the whole fetch path: no network, no
/// timeout, and the first paint is already correct.
enum FontAssets {
    /// Families already handed to Lynx. CoreText refuses to register the same
    /// graphics font twice, and re-reading a CJK font is megabytes per view
    /// creation, so each family is done once per process.
    private static var registered = Set<String>()
    private static let lock = NSLock()

    /// Registers every font in `specs` — the `fonts` entry of the Dart side's
    /// creation params, each a dictionary of `family` and `assetPath`. Call
    /// before creating a `LynxView`.
    static func register(_ specs: [Any]) {
        lock.lock()
        defer { lock.unlock() }

        for spec in specs {
            guard let map = spec as? [String: Any],
                  let family = map["family"] as? String,
                  let assetPath = map["assetPath"] as? String,
                  !family.isEmpty, !assetPath.isEmpty,
                  !registered.contains(family)
            else { continue }

            guard let font = loadFont(assetPath: assetPath) else { continue }
            // The registered face is used as-is and only resized — Lynx does
            // not re-derive a weight from it — which is why one family here is
            // one weight (see `LynxFontAsset` on the Dart side).
            // Not `sharedManager()` / `registerFont(_:forName:)`: the header
            // carries no NS_SWIFT_NAME, so Swift's automatic ObjC renaming
            // applies — it drops the suffix that repeats the class name and the
            // one that repeats the first argument's type.
            LynxFontFaceManager.shared().register(font, forName: family)
            registered.insert(family)
        }
    }

    private static func loadFont(assetPath: String) -> UIFont? {
        // Flutter rewrites asset keys on the way into the bundle, and its
        // lookup is the only thing that knows the mapping.
        let key = FlutterDartProject.lookupKey(forAsset: assetPath)
        guard let path = Bundle.main.path(forResource: key, ofType: nil),
              let data = FileManager.default.contents(atPath: path),
              let provider = CGDataProvider(data: data as CFData),
              let cgFont = CGFont(provider),
              let postScriptName = cgFont.postScriptName as String?
        else {
            // A font that will not load must not take the screen down with it.
            // Skipping it leaves Lynx on the system font — the same harmless
            // fallback an app that never called this already renders.
            NSLog("[lynx_view] Could not load font asset \(assetPath)")
            return nil
        }

        // Registration is per-process and survives this call failing with
        // `kCTFontManagerErrorAlreadyRegistered` — another copy of the same
        // file (the host app's own CoreText registration, say) is fine, the
        // PostScript name still resolves below.
        _ = CTFontManagerRegisterGraphicsFont(cgFont, nil)

        guard let font = UIFont(name: postScriptName, size: UIFont.systemFontSize) else {
            NSLog("[lynx_view] Font \(assetPath) registered but \(postScriptName) did not resolve")
            return nil
        }
        return font
    }
}
