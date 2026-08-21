package com.geektree0101.lynx_view_android

import com.lynx.react.bridge.JavaOnlyArray
import com.lynx.react.bridge.JavaOnlyMap

/**
 * Deep-converts a payload that arrived over a Flutter [MethodChannel] into the
 * types Lynx's bridge accepts.
 *
 * `JavaOnlyMap.from`/`JavaOnlyArray.from` validate only the *top* level: they
 * copy their entries across as-is, and the nested `LinkedHashMap`/`ArrayList`
 * that Flutter's `StandardMessageCodec` decodes into is not something Lynx
 * knows. The value survives the copy and blows up later, when Lynx reads it
 * back — `JavaOnlyMap.getType` throws
 * `IllegalArgumentException: Invalid value {...} for key ... contained in
 * JavaOnlyMap`. Nothing on that path catches it, so the bundle only ever sees
 * `cannot convert to object` and its listener never fires.
 *
 * Lynx accepts `Boolean`, `String`, `Number`, `byte[]`, `ByteBuffer` and its
 * own `ReadableMap`/`ReadableArray`, so containers have to be rebuilt all the
 * way down instead of handed over whole. Leaves pass through untouched.
 *
 * Lives outside [LynxPlatformView] so it can be tested without a live
 * `LynxView`.
 */
internal fun toLynxValue(value: Any?): Any? = when (value) {
    is Map<*, *> -> JavaOnlyMap().apply {
        value.forEach { (key, nested) -> put(key.toString(), toLynxValue(nested)) }
    }
    is List<*> -> JavaOnlyArray().apply {
        value.forEach { nested -> add(toLynxValue(nested)) }
    }
    else -> value
}
