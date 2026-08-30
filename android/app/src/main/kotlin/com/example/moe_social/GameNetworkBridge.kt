package com.example.moe_social

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Bridges packets from the Android VPN service to Flutter while the
 * experiment page is active.
 */
object GameNetworkBridge {
    @Volatile
    var packetSink: EventChannel.EventSink? = null

    @Volatile
    var status: String = "stopped"

    private val mainHandler = Handler(Looper.getMainLooper())

    fun emitPacket(packet: ByteArray) {
        mainHandler.post {
            packetSink?.success(packet)
        }
    }
}
