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
                    val packageName = AppPackages.getPackageName(appName)
                    
                    if (packageName == null) {
                        result.error("APP_NOT_FOUND", "未找到应用: $appName", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        val intent = packageManager.getLaunchIntentForPackage(packageName)
                        if (intent != null) {
                            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("NO_LAUNCHER", "应用无启动Activity: $appName", null)
                        }
                    } catch (e: Exception) {
                        result.error("LAUNCH_FAILED", "启动失败: ${e.message}", null)
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
                "showInputMethodPicker" -> {
                    val imm = getSystemService(android.content.Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                    imm.showInputMethodPicker()
                    result.success(true)
                }
                "saveCurrentIme" -> {
                    service.saveCurrentIme()
                    result.success(true)
                }
                "isAdbKeyboardEnabled" -> {
                    val imm = getSystemService(android.content.Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                    val enabledInputMethods = imm.enabledInputMethodList
                    val isEnabled = enabledInputMethods.any { it.id.contains("com.android.adbkeyboard/.AdbIME") }
                    result.success(isEnabled)
                }
                "isAdbKeyboardSelected" -> {
                    val currentId = Settings.Secure.getString(contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
                    val isSelected = currentId != null && currentId.contains("com.android.adbkeyboard/.AdbIME")
                    result.success(isSelected)
                }
                else -> result.notImplemented()
            }
        }
    }
}
