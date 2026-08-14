package com.geektree0101.lynx_view_android

import android.content.Context
import android.graphics.Typeface
import com.lynx.tasm.base.LLog
import com.lynx.tasm.behavior.shadow.text.TypefaceCache
import io.flutter.FlutterInjector

/**
 * Hands host-supplied font files to Lynx, so a template can select them with
 * `font-family`.
 *
 * Lynx never loads a font by itself. `@font-face src: url()` is delegated to a
 * resource fetcher this package does not ship, and the built-in font loader
 * only understands `local()` and inline `data:` URIs — so a template naming a
 * font nobody registered silently draws in the system font. Registering the
 * file the host app already ships skips the whole fetch path: no network, no
 * timeout, and the first paint is already correct.
 */
internal object FontAssets {
    /**
     * Lynx keys its typeface cache by (family, style) and answers only for the
     * exact style asked for — [TypefaceCache.getCachedTypeface] does not fall
     * back to the regular slot. A family here is a single weight, so the same
     * file has to answer for all four: a template asking for `font-weight: 700`
     * resolves to [Typeface.BOLD], and leaving that slot empty is what makes
     * Lynx synthesize a bold on top of an already-bold file.
     */
    private val STYLES = intArrayOf(
        Typeface.NORMAL,
        Typeface.BOLD,
        Typeface.ITALIC,
        Typeface.BOLD_ITALIC,
    )

    /**
     * Registers every font in [specs] — the `fonts` entry of the Dart side's
     * creation params, each a map of `family` and `assetPath`. Call before
     * building a `LynxView`; already-registered families are skipped.
     */
    fun register(context: Context, specs: List<*>) {
        for (spec in specs) {
            val map = spec as? Map<*, *> ?: continue
            val family = map["family"] as? String ?: continue
            val assetPath = map["assetPath"] as? String ?: continue
            if (family.isEmpty() || assetPath.isEmpty()) continue
            // The cache is process-wide, and decoding a CJK font is tens of
            // milliseconds — without this every platform view creation pays it
            // again for the same file.
            if (TypefaceCache.containsTypeface(family)) continue

            val typeface = loadTypeface(context, assetPath) ?: continue
            for (style in STYLES) {
                TypefaceCache.cacheTypeface(family, style, typeface)
            }
        }
    }

    private fun loadTypeface(context: Context, assetPath: String): Typeface? = try {
        // Flutter rewrites asset keys on the way into the APK, and its loader
        // is the only thing that knows the mapping — `assets/fonts/x.otf` in
        // pubspec.yaml is not the path AssetManager wants.
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
        Typeface.createFromAsset(context.assets, key)
    } catch (e: RuntimeException) {
        // A font that will not load must not take the screen down with it.
        // Skipping it leaves Lynx on the system font, which is exactly what an
        // app that never called this renders — the same harmless fallback.
        LLog.w("lynx_view", "Could not load font asset $assetPath: $e")
        null
    }
}
