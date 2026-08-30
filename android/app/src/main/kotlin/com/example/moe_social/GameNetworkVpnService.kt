package com.example.moe_social

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import okio.ByteString.Companion.toByteString
import org.json.JSONObject
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/**
 * Owns the VPN interface and relay WebSocket so game traffic continues while
 * the Flutter activity is in the background.
 */
class GameNetworkVpnService : VpnService() {
    companion object {
        const val ACTION_START = "com.example.moe_social.game_network.START"
        const val ACTION_STOP = "com.example.moe_social.game_network.STOP"

        const val EXTRA_ROLE = "role"
        const val EXTRA_ROOM_ID = "roomId"
        const val EXTRA_RELAY_URL = "relayUrl"
        const val EXTRA_TOKEN = "token"

        private const val ROLE_HOST = "host"
        private const val HOST_ADDRESS = "10.66.0.1"
        private const val GUEST_ADDRESS = "10.66.0.2"
        private const val VIRTUAL_NETWORK = "10.66.0.0"
        private const val VIRTUAL_PREFIX = 24
        private const val MTU = 1400
        private const val MAX_PACKET_SIZE = 65535
        private const val NOTIFICATION_CHANNEL_ID = "game_network"
        private const val NOTIFICATION_ID = 24642
        private const val RELAY_PING_INTERVAL_SECONDS = 20L
        private const val BASE_RECONNECT_DELAY_MS = 3000L
        private const val MAX_RECONNECT_DELAY_MS = 30000L

        @Volatile
        private var instance: GameNetworkVpnService? = null

        fun writePacket(packet: ByteArray): Boolean {
            return instance?.writePacketInternal(packet) == true
        }

        fun snapshot(): Map<String, Any> {
            val service = instance
            return mapOf(
                "running" to (service?.running?.get() == true),
                "role" to (service?.role ?: ""),
                "localIp" to (service?.localAddress ?: ""),
                "relayConnected" to (service?.relayConnected == true),
                "peerCount" to (service?.peerCount ?: 0),
                "sentPackets" to (service?.sentPackets?.get() ?: 0L),
                "receivedPackets" to (service?.receivedPackets?.get() ?: 0L),
                "status" to (service?.relayStatus ?: "stopped"),
            )
        }
    }

    private val running = AtomicBoolean(false)
    private val ioLock = Any()
    private val relayLock = Any()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val relayClient = OkHttpClient.Builder()
        .pingInterval(RELAY_PING_INTERVAL_SECONDS, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()
    private val sentPackets = AtomicLong(0)
    private val receivedPackets = AtomicLong(0)

    private var vpnInterface: ParcelFileDescriptor? = null
    private var inputStream: FileInputStream? = null
    private var outputStream: FileOutputStream? = null
    private var ioThread: Thread? = null
    private var reconnectRunnable: Runnable? = null
    private var reconnectAttempt = 0
    private var relaySocket: WebSocket? = null
    private var relayRoomId = ""
    private var relayRole = ""
    private var relayBaseUrl = ""
    private var relayToken: String? = null

    @Volatile
    private var relayConnected = false

    @Volatile
    private var peerCount = 0

    @Volatile
    private var relayStatus = "stopped"

    private var role: String = ""
    private var localAddress: String = ""

    private val relayListener = object : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            if (!isCurrentSocket(webSocket)) {
                webSocket.close(1000, "stale")
                return
            }
            reconnectAttempt = 0
            relayConnected = true
            relayStatus = "等待另一端加入"
            val hello = JSONObject()
                .put("type", "hello")
                .put("room_id", relayRoomId)
                .put("role", relayRole)
                .put("virtual_ip", localAddress)
                .toString()
            if (!webSocket.send(hello)) {
                handleRelayDisconnected(webSocket, "房间中继发送失败")
            }
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            if (!isCurrentSocket(webSocket)) {
                return
            }
            handleRelayMessage(text)
        }

        override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
            if (!isCurrentSocket(webSocket) || !running.get()) {
                return
            }
            if (writePacketInternal(bytes.toByteArray())) {
                receivedPackets.incrementAndGet()
            }
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            webSocket.close(code, reason)
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            handleRelayDisconnected(webSocket, "房间中继已断开")
        }

        override fun onFailure(
            webSocket: WebSocket,
            t: Throwable,
            response: Response?,
        ) {
            handleRelayDisconnected(
                webSocket,
                "房间中继断开：${t.message ?: "网络错误"}",
            )
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startTunnel(intent)
            ACTION_STOP -> stopTunnel()
        }
        return START_REDELIVER_INTENT
    }

    override fun onDestroy() {
        stopTunnel()
        relayClient.dispatcher.executorService.shutdown()
        super.onDestroy()
    }

    private fun startTunnel(intent: Intent) {
        if (running.get()) {
            return
        }

        val requestedRole = intent.getStringExtra(EXTRA_ROLE)
        val requestedRoomId = intent.getStringExtra(EXTRA_ROOM_ID)?.trim()
        val requestedRelayUrl = intent.getStringExtra(EXTRA_RELAY_URL)?.trim()
        val requestedToken = intent.getStringExtra(EXTRA_TOKEN)?.trim()
        if (requestedRoomId.isNullOrEmpty() || requestedRelayUrl.isNullOrEmpty()) {
            relayStatus = "error:联机参数缺失"
            stopSelf()
            return
        }

        role = if (requestedRole == ROLE_HOST) ROLE_HOST else "guest"
        localAddress = if (role == ROLE_HOST) HOST_ADDRESS else GUEST_ADDRESS
        relayRoomId = requestedRoomId
        relayRole = role
        relayBaseUrl = requestedRelayUrl
        relayToken = requestedToken?.takeIf { it.isNotEmpty() }
        instance = this

        try {
            createNotificationChannel()
            startForeground(NOTIFICATION_ID, buildNotification())
            val builder = Builder()
                .setSession("Moe Social game network")
                .setMtu(MTU)
                .addAddress(localAddress, VIRTUAL_PREFIX)
                .addRoute(VIRTUAL_NETWORK, VIRTUAL_PREFIX)
            val established = builder.establish()
                ?: throw IllegalStateException("VPN interface unavailable")
            vpnInterface = established
            inputStream = FileInputStream(established.fileDescriptor)
            outputStream = FileOutputStream(established.fileDescriptor)
            running.set(true)
            relayStatus = "正在连接房间中继"
            startReadLoop()
            connectRelay()
        } catch (error: Exception) {
            relayStatus = "error:${error.message ?: "start_failed"}"
            stopTunnel()
        }
    }

    private fun startReadLoop() {
        val input = inputStream ?: return
        ioThread = Thread {
            val buffer = ByteArray(MAX_PACKET_SIZE)
            try {
                while (running.get()) {
                    val length = input.read(buffer)
                    if (length > 0) {
                        val socket = relaySocket
                        if (socket?.send(buffer.toByteString(0, length)) == true) {
                            sentPackets.incrementAndGet()
                        }
                    }
                }
            } catch (_: Exception) {
                if (running.get()) {
                    relayStatus = "虚拟网卡读取失败"
                }
            }
        }.apply {
            name = "game-network-tun-reader"
            start()
        }
    }

    private fun connectRelay() {
        if (!running.get()) {
            return
        }
        val request = try {
            val requestBuilder = Request.Builder().url(buildRelayUrl())
            relayToken?.let { token ->
                requestBuilder.addHeader("Authorization", "Bearer $token")
            }
            requestBuilder.build()
        } catch (_: Exception) {
            relayStatus = "中继地址无效"
            scheduleRelayReconnect()
            return
        }

        try {
            synchronized(relayLock) {
                if (relaySocket != null || !running.get()) {
                    return
                }
                relaySocket = relayClient.newWebSocket(request, relayListener)
            }
        } catch (_: Exception) {
            relayStatus = "中继连接失败"
            scheduleRelayReconnect()
        }
    }

    private fun buildRelayUrl(): String {
        val base = Uri.parse(relayBaseUrl)
        val scheme = if (base.scheme.equals("https", ignoreCase = true)) {
            "wss"
        } else {
            "ws"
        }
        return base.buildUpon()
            .scheme(scheme)
            .path("/ws/game-network")
            .clearQuery()
            .fragment(null)
            .appendQueryParameter("room_id", relayRoomId)
            .appendQueryParameter("role", relayRole)
            .appendQueryParameter("virtual_ip", localAddress)
            .apply {
                relayToken?.let { appendQueryParameter("token", it) }
            }
            .build()
            .toString()
    }

    private fun handleRelayMessage(text: String) {
        val message = try {
            JSONObject(text)
        } catch (_: Exception) {
            return
        }
        when (message.optString("type")) {
            "peer_count", "peer_joined", "peer_left" -> {
                peerCount = message.optInt("count", peerCount)
                relayStatus = if (peerCount >= 2) {
                    "两端已连接"
                } else {
                    "等待另一端加入"
                }
            }
            "joined" -> {
                relayStatus = "等待另一端加入"
            }
            "pong" -> Unit
            "error" -> {
                relayStatus = message.optString("message", "中继错误")
            }
        }
    }

    private fun handleRelayDisconnected(webSocket: WebSocket, message: String) {
        synchronized(relayLock) {
            if (relaySocket !== webSocket) {
                return
            }
            relaySocket = null
        }
        relayConnected = false
        peerCount = 0
        if (running.get()) {
            relayStatus = "$message，正在重连"
            scheduleRelayReconnect()
        }
    }

    private fun scheduleRelayReconnect() {
        if (!running.get()) {
            return
        }
        synchronized(relayLock) {
            if (reconnectRunnable != null || relaySocket != null) {
                return
            }
            val multiplier = 1L shl reconnectAttempt.coerceAtMost(3)
            val delay = (BASE_RECONNECT_DELAY_MS * multiplier)
                .coerceAtMost(MAX_RECONNECT_DELAY_MS)
            reconnectAttempt = (reconnectAttempt + 1).coerceAtMost(4)
            val runnable = Runnable {
                synchronized(relayLock) {
                    reconnectRunnable = null
                }
                connectRelay()
            }
            reconnectRunnable = runnable
            mainHandler.postDelayed(runnable, delay)
        }
    }

    private fun isCurrentSocket(webSocket: WebSocket): Boolean {
        synchronized(relayLock) {
            return relaySocket === webSocket
        }
    }

    private fun writePacketInternal(packet: ByteArray): Boolean {
        if (!running.get() || packet.isEmpty() || packet.size > MAX_PACKET_SIZE) {
            return false
        }
        val stream = outputStream ?: return false
        return try {
            synchronized(ioLock) {
                stream.write(packet)
                stream.flush()
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun stopTunnel() {
        running.set(false)
        synchronized(relayLock) {
            reconnectRunnable?.let { mainHandler.removeCallbacks(it) }
            reconnectRunnable = null
            relaySocket?.close(1000, "stopped")
            relaySocket = null
        }
        relayConnected = false
        peerCount = 0
        relayStatus = "stopped"
        reconnectAttempt = 0
        ioThread?.interrupt()
        ioThread = null
        synchronized(ioLock) {
            try {
                inputStream?.close()
            } catch (_: Exception) {
            }
            try {
                outputStream?.close()
            } catch (_: Exception) {
            }
            inputStream = null
            outputStream = null
        }
        try {
            vpnInterface?.close()
        } catch (_: Exception) {
        }
        vpnInterface = null
        instance = null
        stopForeground(true)
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "异地联机实验",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "显示虚拟网络实验的连接状态"
        }
        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, flags)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("异地联机实验运行中")
            .setContentText("虚拟地址：$localAddress")
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
