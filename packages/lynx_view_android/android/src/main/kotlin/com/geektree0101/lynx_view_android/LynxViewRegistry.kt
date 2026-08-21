package com.geektree0101.lynx_view_android

import io.flutter.plugin.common.MethodChannel

/**
 * Maps a Flutter-assigned `viewId` to the per-instance [MethodChannel] used
 * to talk to that view's Dart-side [LynxViewController].
 *
 * [FlutterBridgeModule] instances are constructed by the Lynx engine per
 * `LynxView`, each carrying its view's id as a constructor param, and use
 * this registry to turn that id back into the right Dart channel.
 */
internal object LynxViewRegistry {
    private val channels = mutableMapOf<Int, MethodChannel>()

    fun register(viewId: Int, channel: MethodChannel) {
        channels[viewId] = channel
    }

    fun unregister(viewId: Int) {
        channels.remove(viewId)
    }

    fun channelFor(viewId: Int): MethodChannel? = channels[viewId]
}
