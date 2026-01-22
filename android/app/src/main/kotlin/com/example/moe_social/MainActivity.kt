package com.example.moe_social

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.os.Build
import android.widget.Toast

import android.content.Intent
import android.provider.Settings

import android.net.Uri

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.moe_social/autoglm"
    private var lastImeIdLogged: String? = null
    private var lastIsAdbLogged: Boolean? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.moe_social/autoglm_logs").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    AutoGLMAccessibilityService.logListener = { log ->
                        runOnUiThread {
                            try {
                                events?.success(log)
                            } catch (e: Exception) {}
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    AutoGLMAccessibilityService.logListener = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openAccessibilitySettings") {
                val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                startActivity(intent)
                result.success(true)
                return@setMethodCallHandler
            }

            if (call.method == "checkOverlayPermission") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    result.success(Settings.canDrawOverlays(this))
                } else {
                    result.success(true)
                }
                return@setMethodCallHandler
            }

            if (call.method == "requestOverlayPermission") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                    startActivity(intent)
                }
                result.success(true)
                return@setMethodCallHandler
            }

            // 这些方法不需要 AccessibilityService，提前处理
            if (call.method == "showInputMethodPicker") {
                val mode = call.argument<String>("mode") ?: "to_non_adb"
                println("📱 [IME] 通过 ImePickerActivity 弹出输入法选择器, mode=$mode")
                try {
                    val intent = Intent(this, ImePickerActivity::class.java)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    intent.putExtra("mode", mode)
                    startActivity(intent)
                } catch (e: Exception) {
                    // 兜底：如果 Activity 拉起失败，再尝试直接弹
                    try {
                        val imm = getSystemService(android.content.Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                        imm.showInputMethodPicker()
                    } catch (_: Exception) {}
                }
                result.success(true)
                return@setMethodCallHandler
            }
            
            if (call.method == "isAdbKeyboardEnabled") {
                val imm = getSystemService(android.content.Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                val enabledInputMethods = imm.enabledInputMethodList
                val isEnabled = enabledInputMethods.any { 
                    it.id.contains("adbkeyboard", ignoreCase = true) ||
                    it.id.contains("AdbIME", ignoreCase = true)
                }
                println("📱 [IME] ADB Keyboard 已启用: $isEnabled")
                result.success(isEnabled)
                return@setMethodCallHandler
            }
            
            if (call.method == "isAdbKeyboardSelected") {
                val currentId = Settings.Secure.getString(contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
                val isSelected = currentId != null && (
                    currentId.contains("adbkeyboard", ignoreCase = true) ||
                    currentId.contains("AdbIME", ignoreCase = true)
                )
                // 只在变化时输出，避免频繁轮询导致卡顿/刷屏
                if (currentId != lastImeIdLogged || isSelected != lastIsAdbLogged) {
                    println("📱 [IME] 当前输入法: $currentId, 是ADB: $isSelected")
                    lastImeIdLogged = currentId
                    lastIsAdbLogged = isSelected
                }
                result.success(isSelected)
                return@setMethodCallHandler
            }

            val service = AutoGLMAccessibilityService.instance

            if (service == null) {
                // 如果服务没开启
                if (call.method == "checkService") {
                    result.success(false)
                    return@setMethodCallHandler
                }
                // 对于需要服务的操作，返回错误
                result.error("SERVICE_NOT_RUNNING", "请先在无障碍设置中开启 Moe Social 助手", null)
                return@setMethodCallHandler
            }

            when (call.method) {
                "checkService" -> {
                    result.success(true)
                }
                "getInstalledApps" -> {
                    val installedApps = service.getInstalledApps()
                    result.success(installedApps)
                }
                "launchApp" -> {
                    val appName = call.argument<String>("appName") ?: ""
                    
                    // 使用 AccessibilityService 的增强版 launchApp（支持模糊匹配）
                    val success = service.launchApp(appName)
                    
                    if (success) {
                        result.success(true)
                    } else {
                        result.error("APP_NOT_FOUND", "未找到应用: $appName", null)
                    }
                }
                "performType" -> {
                    val text = call.argument<String>("text") ?: ""
                    // 直接调用服务方法，服务方法会处理切换/不切换逻辑
                    service.performType(text)
                    result.success(true)
                }
                "enableInputMode" -> {
                    service.enableInputMode()
                    result.success(true)
                }
                "disableInputMode" -> {
                    service.disableInputMode()
                    result.success(true)
                }
                "switchToAdbKeyboard" -> {
                    val ime = service.switchToAdbKeyboard()
                    result.success(ime)
                }
                "restoreKeyboard" -> {
                    val ime = call.argument<String>("ime")
                    service.restoreKeyboard(ime)
                    result.success(true)
                }
                "clearText" -> {
                    service.clearText()
                    result.success(true)
                }
                "performClick" -> {
                    val x = call.argument<Double>("x")?.toFloat() ?: 0f
                    val y = call.argument<Double>("y")?.toFloat() ?: 0f
                    service.performClick(x, y) // Now expects relative 0-1000
                    result.success(true)
                }
                "performSwipe" -> {
                    val x1 = call.argument<Double>("x1")?.toFloat() ?: 0f
                    val y1 = call.argument<Double>("y1")?.toFloat() ?: 0f
                    val x2 = call.argument<Double>("x2")?.toFloat() ?: 0f
                    val y2 = call.argument<Double>("y2")?.toFloat() ?: 0f
                    val duration = call.argument<Int>("duration")?.toLong() ?: 500L
                    service.performSwipe(x1, y1, x2, y2, duration)
                    result.success(true)
                }
                "performBack" -> {
                    service.performBack()
                    result.success(true)
                }
                "performHome" -> {
                    service.performHome()
                    result.success(true)
                }
                "showOverlay" -> {
                    service.showOverlay()
                    result.success(true)
                }
                "updateOverlayLog" -> {
                    val log = call.argument<String>("log") ?: ""
                    service.updateOverlayLog(log)
                    result.success(true)
                }
                "updateOverlayStatus" -> {
                    val status = call.argument<String>("status") ?: ""
                    val isRunning = call.argument<Boolean>("isRunning") ?: false
                    service.updateStatus(status, isRunning)
                    result.success(true)
                }
                "updateOverlayProgress" -> {
                    val step = call.argument<Int>("step") ?: 0
                    val total = call.argument<Int>("total") ?: 20
                    service.updateProgress(step, total)
                    result.success(true)
                }
                "removeOverlay" -> {
                    service.removeOverlay()
                    result.success(true)
                }
                "getScreenshot" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        service.takeScreenShot { base64 ->
                            if (base64 != null) {
                                result.success(base64)
                            } else {
                                result.error("SCREENSHOT_FAILED", "截图失败", null)
                            }
                        }
                    } else {
                        result.error("VERSION_TOO_LOW", "截图功能需要 Android 11及以上", null)
                    }
                }
                "saveCurrentIme" -> {
                    service.saveCurrentIme()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
