package com.example.moe_social

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * 把回复参谋的 Flutter 引擎和 MethodChannel 挂在进程内缓存上，
 * 不随 MainActivity 销毁而断开，供无障碍服务点脸后直接请求草稿。
 */
object ReplyAssistFlutterHost {
    const val ENGINE_ID = "moe_reply_assist_engine"

    fun cache(engine: FlutterEngine) {
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    fun cachedEngine(): FlutterEngine? = FlutterEngineCache.getInstance().get(ENGINE_ID)

    fun bind(context: Context, engine: FlutterEngine) {
        cache(engine)
        val app = context.applicationContext
        val channel = MethodChannel(
            engine.dartExecutor.binaryMessenger,
            ReplyAssistBridge.CHANNEL,
        )
        ReplyAssistBridge.channel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    result.success(ReplyAssistAccessibilityService.isServiceEnabled(app))
                }
                "isOverlayVisible" -> {
                    val svc = ReplyAssistAccessibilityService.getInstance()
                    result.success(svc?.isOverlayVisible() == true)
                }
                "isOverlayPermissionGranted" -> {
                    result.success(canDrawOverlays(app))
                }
                "openAccessibilitySettings" -> {
                    app.startActivity(
                        Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(true)
                }
                "openOverlaySettings" -> {
                    openOverlayPermissionSettings(app)
                    result.success(true)
                }
                "toggleOverlay" -> {
                    if (!canDrawOverlays(app)) {
                        result.error("OVERLAY_OFF", "需要悬浮窗权限", null)
                        return@setMethodCallHandler
                    }
                    val svc = ReplyAssistAccessibilityService.getInstance()
                    if (svc == null) {
                        result.error("A11Y_OFF", "请先开启 Moe 回复参谋无障碍", null)
                        return@setMethodCallHandler
                    }
                    result.success(svc.toggleOverlay())
                }
                "readForegroundSnapshot", "readWeChatSnapshot" -> {
                    val svc = ReplyAssistAccessibilityService.getInstance()
                    val json = svc?.readForegroundSnapshot() ?: ReplyAssistBridge.lastSnapshot
                    result.success(ReplyAssistBridge.jsonToMap(json))
                }
                "setAdultMode", "setAdultIntimate" -> {
                    val enabled = when (val arg = call.arguments) {
                        is Boolean -> arg
                        is Map<*, *> -> arg["enabled"] as? Boolean ?: arg["adult_intimate"] as? Boolean ?: false
                        else -> false
                    }
                    ReplyAssistAdultSettings.setEnabled(enabled)
                    result.success(true)
                }
                "isAdultMode", "isAdultIntimate" -> {
                    result.success(ReplyAssistAdultSettings.isEnabled(app))
                }
                else -> result.notImplemented()
            }
        }
    }

    fun suggestChannel(): MethodChannel? = ReplyAssistBridge.channel

    fun ensureChannel(context: Context): MethodChannel? {
        suggestChannel()?.let { return it }
        val engine = cachedEngine() ?: return null
        bind(context, engine)
        return suggestChannel()
    }

    private fun canDrawOverlays(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    private fun openOverlayPermissionSettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        context.startActivity(
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${context.packageName}"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}
