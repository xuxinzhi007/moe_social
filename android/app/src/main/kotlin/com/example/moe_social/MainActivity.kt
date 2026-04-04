package com.example.moe_social

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.os.Build
import android.widget.Toast

import android.content.Intent
import android.provider.Settings
import android.content.Context

import android.net.Uri
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.moe_social/autoglm"
    private val PREFS_NAME = "moe_prefs"
    private val KEY_INPUT_ASSIST_ENABLED = "input_assist_enabled"
    private var lastImeIdLogged: String? = null
    private var lastIsAdbLogged: Boolean? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.moe_social/app_update").setMethodCallHandler { call, result ->
            when (call.method) {
                "compareApkSignatureWithInstalled" -> {
                    val path = call.argument<String>("apkPath")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID", "apkPath required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(compareApkSigningWithInstalled(path))
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "requestUninstallCurrentApp" -> {
                    try {
                        val intent = Intent(Intent.ACTION_UNINSTALL_PACKAGE).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

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

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.moe_social/accessibility_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    AutoGLMAccessibilityService.accessibilityEventListener = { eventType, data ->
                        runOnUiThread {
                            try {
                                events?.success(mapOf("type" to eventType, "data" to data))
                            } catch (e: Exception) {}
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    AutoGLMAccessibilityService.accessibilityEventListener = null
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

            if (call.method == "getInputAssistEnabled") {
                val sp = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                result.success(sp.getBoolean(KEY_INPUT_ASSIST_ENABLED, false))
                return@setMethodCallHandler
            }

            if (call.method == "setInputAssistEnabled") {
                val enabled = call.argument<Boolean>("enabled") ?: false
                val sp = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                sp.edit().putBoolean(KEY_INPUT_ASSIST_ENABLED, enabled).apply()
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
                    // 结束任务：把“原输入法”作为目标，避免切到任意非ADB后就关闭
                    if (mode == "to_non_adb") {
                        val prefs = getSharedPreferences("autoglm_prefs", Context.MODE_PRIVATE)
                        val targetIme = prefs.getString("original_ime", null)
                        if (targetIme != null) {
                            intent.putExtra("targetIme", targetIme)
                        }
                    }
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

    private fun compareApkSigningWithInstalled(apkPath: String): Map<String, Any?> {
        val pm = packageManager
        val myPkg = packageName
        val flags = signingFlags()
        val installedPi = try {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(myPkg, flags)
        } catch (_: Exception) {
            return mapOf("match" to false, "error" to "installed_read_fail")
        }
        val apkPi = pm.getPackageArchiveInfo(apkPath, flags)
            ?: return mapOf("match" to false, "error" to "apk_parse_fail")
        apkPi.applicationInfo?.apply {
            sourceDir = apkPath
            publicSourceDir = apkPath
        }

        val apkPkg = apkPi.packageName ?: return mapOf("match" to false, "error" to "apk_parse_fail")
        if (apkPkg != myPkg) {
            return mapOf(
                "match" to false,
                "error" to "package_name_mismatch",
                "installedPackage" to myPkg,
                "apkPackage" to apkPkg,
            )
        }

        val installedSha = firstSignerSha256(installedPi)
        val apkSha = firstSignerSha256(apkPi)
        if (installedSha == null || apkSha == null) {
            return mapOf(
                "match" to false,
                "error" to "cert_unavailable",
                "installedSha256" to installedSha,
                "apkSha256" to apkSha,
            )
        }
        if (installedSha != apkSha) {
            return mapOf(
                "match" to false,
                "error" to "signing_mismatch",
                "installedSha256" to installedSha,
                "apkSha256" to apkSha,
            )
        }
        return mapOf(
            "match" to true,
            "installedSha256" to installedSha,
            "apkSha256" to apkSha,
        )
    }

    private fun signingFlags(): Int {
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
    }

    private fun firstSignerSha256(pi: PackageInfo): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val si = pi.signingInfo ?: return null
                val sigs: Array<Signature> = si.apkContentsSigners
                if (sigs.isEmpty()) return null
                sha256Hex(sigs[0].toByteArray())
            } else {
                @Suppress("DEPRECATION")
                val sigs = pi.signatures ?: return null
                if (sigs.isEmpty()) return null
                sha256Hex(sigs[0].toByteArray())
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun sha256Hex(bytes: ByteArray): String {
        val d = MessageDigest.getInstance("SHA-256").digest(bytes)
        return d.joinToString("") { b -> "%02x".format(b.toInt() and 0xff) }
    }
}
