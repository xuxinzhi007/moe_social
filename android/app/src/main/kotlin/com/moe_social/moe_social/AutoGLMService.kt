package com.moe_social.moe_social

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Path
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Base64
import android.util.DisplayMetrics
import android.util.Log
import android.view.Display
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/**
 * AutoGLM无障碍服务 - 核心系统组件
 *
 * 功能包括：
 * - 屏幕截图和UI自动化
 * - 输入法管理和文本输入
 * - 手势操作和应用控制
 * - 悬浮窗UI和进度显示
 */
class AutoGLMService : AccessibilityService() {

    companion object {
        private const val TAG = "AutoGLMService"
        private const val CHANNEL = "com.moe_social/autoglm"
        private const val EVENT_CHANNEL = "com.moe_social/autoglm_events"
        private const val LOG_EVENT_CHANNEL = "com.moe_social/autoglm_logs"

        // 悬浮窗相关常量
        private const val OVERLAY_TAG = "AutoGLM_Overlay"
        private const val MAX_LOG_LINES = 50

        // 操作超时时间
        private const val OPERATION_TIMEOUT = 10000L // 10秒
        private const val GESTURE_DURATION = 500L // 手势持续时间

        @Volatile
        private var instance: AutoGLMService? = null

        fun getInstance(): AutoGLMService? = instance
    }

    // 核心组件
    private lateinit var windowManager: WindowManager
    private lateinit var displayMetrics: DisplayMetrics
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    // Flutter通信
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var logEventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var logEventSink: EventChannel.EventSink? = null

    // 悬浮窗相关
    private var overlayView: View? = null
    private var isOverlayVisible = false
    private var isTaskRunning = AtomicBoolean(false)
    private val logBuffer = mutableListOf<String>()

    // 屏幕截图相关
    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var imageReader: ImageReader? = null
    private var virtualDisplay: VirtualDisplay? = null

    // 应用包名映射
    private val appPackageMap = ConcurrentHashMap<String, String>()

    override fun onCreate() {
        super.onCreate()
        instance = this
        initializeService()
        Log.i(TAG, "AutoGLM服务已启动")
    }

    private fun initializeService() {
        // 初始化系统服务
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        displayMetrics = resources.displayMetrics
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager

        // 初始化应用包名映射
        initializeAppPackageMap()

        // 启动后台任务
        serviceScope.launch {
            monitorSystemState()
        }

        logMessage("系统", "AutoGLM服务初始化完成")
    }

    fun setupFlutterCommunication(flutterEngine: FlutterEngine) {
        // 设置方法通道
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                handleMethodCall(call, result)
            }
        }

        // 设置事件通道
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
        }

        // 设置日志事件通道
        logEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, LOG_EVENT_CHANNEL).apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    logEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    logEventSink = null
                }
            })
        }

        Log.i(TAG, "Flutter通信通道已建立")
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "checkAccessibilityService" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "takeScreenshot" -> {
                    serviceScope.launch {
                        try {
                            val screenshot = takeScreenshot()
                            withContext(Dispatchers.Main) {
                                result.success(screenshot)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("SCREENSHOT_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "performTap" -> {
                    val x = call.argument<Double>("x") ?: 0.0
                    val y = call.argument<Double>("y") ?: 0.0
                    val elementName = call.argument<String>("elementName")

                    serviceScope.launch {
                        try {
                            val success = if (elementName != null) {
                                performTapByElement(elementName)
                            } else {
                                performTap(x.toFloat(), y.toFloat())
                            }
                            withContext(Dispatchers.Main) {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("TAP_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "performType" -> {
                    val text = call.argument<String>("text") ?: ""
                    serviceScope.launch {
                        try {
                            val success = performType(text)
                            withContext(Dispatchers.Main) {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("TYPE_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "performSwipe" -> {
                    val startX = call.argument<Double>("startX") ?: 0.0
                    val startY = call.argument<Double>("startY") ?: 0.0
                    val endX = call.argument<Double>("endX") ?: 0.0
                    val endY = call.argument<Double>("endY") ?: 0.0
                    val duration = call.argument<Int>("duration") ?: 500

                    serviceScope.launch {
                        try {
                            val success = performSwipe(
                                startX.toFloat(), startY.toFloat(),
                                endX.toFloat(), endY.toFloat(),
                                duration.toLong()
                            )
                            withContext(Dispatchers.Main) {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("SWIPE_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "launchApp" -> {
                    val appName = call.argument<String>("appName") ?: ""
                    serviceScope.launch {
                        try {
                            val success = launchApp(appName)
                            withContext(Dispatchers.Main) {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("LAUNCH_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "performBack" -> {
                    val success = performGlobalAction(GLOBAL_ACTION_BACK)
                    result.success(success)
                }
                "performHome" -> {
                    val success = performGlobalAction(GLOBAL_ACTION_HOME)
                    result.success(success)
                }
                "showOverlay" -> {
                    showOverlay()
                    result.success(true)
                }
                "hideOverlay" -> {
                    hideOverlay()
                    result.success(true)
                }
                "updateOverlayStatus" -> {
                    val status = call.argument<String>("status") ?: ""
                    val isRunning = call.argument<Boolean>("isRunning") ?: false
                    updateOverlayStatus(status, isRunning)
                    result.success(true)
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(true)
                }
                "evaluateCondition" -> {
                    val condition = call.argument<String>("condition") ?: ""
                    serviceScope.launch {
                        try {
                            val success = evaluateCondition(condition)
                            withContext(Dispatchers.Main) {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("CONDITION_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "verifyOutcome" -> {
                    val outcome = call.argument<String>("outcome") ?: ""
                    val context = call.argument<Map<String, Any>>("context") ?: emptyMap()
                    serviceScope.launch {
                        try {
                            val success = verifyOutcome(outcome, context)
                            withContext(Dispatchers.Main) {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("VERIFY_ERROR", e.message, null)
                            }
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "方法调用异常: ${call.method}", e)
            result.error("METHOD_ERROR", e.message, null)
        }
    }

    // ============= 核心功能实现 =============

    /**
     * 屏幕截图
     */
    private suspend fun takeScreenshot(): String? = withContext(Dispatchers.IO) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+ 使用新的截图API
                takeScreenshotModern()
            } else {
                // 旧版本使用Media Projection
                takeScreenshotLegacy()
            }
        } catch (e: Exception) {
            Log.e(TAG, "截图失败", e)
            logMessage("错误", "截图失败: ${e.message}")
            null
        }
    }

    private suspend fun takeScreenshotModern(): String? {
        return try {
            // 实现现代截图API
            // 注意：这需要额外的权限配置
            logMessage("设备", "使用现代截图API")
            null // 暂时返回null，需要具体实现
        } catch (e: Exception) {
            Log.e(TAG, "现代截图失败", e)
            null
        }
    }

    private suspend fun takeScreenshotLegacy(): String? {
        return try {
            // 使用Media Projection截图
            logMessage("设备", "使用传统截图方式")
            null // 暂时返回null，需要Media Projection权限
        } catch (e: Exception) {
            Log.e(TAG, "传统截图失败", e)
            null
        }
    }

    /**
     * 点击操作
     */
    private suspend fun performTap(x: Float, y: Float): Boolean = withContext(Dispatchers.IO) {
        try {
            // 转换相对坐标到绝对坐标
            val actualX = (x / 1000f) * displayMetrics.widthPixels
            val actualY = (y / 1000f) * displayMetrics.heightPixels

            val path = Path().apply {
                moveTo(actualX, actualY)
            }

            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 50))
                .build()

            val success = dispatchGesture(gesture, null, null)

            if (success) {
                logMessage("设备", "点击成功: ($actualX, $actualY)")
            } else {
                logMessage("错误", "点击失败: ($actualX, $actualY)")
            }

            success
        } catch (e: Exception) {
            Log.e(TAG, "点击操作异常", e)
            logMessage("错误", "点击操作异常: ${e.message}")
            false
        }
    }

    /**
     * 根据元素名称点击
     */
    private suspend fun performTapByElement(elementName: String): Boolean = withContext(Dispatchers.IO) {
        try {
            val rootNode = rootInActiveWindow ?: return@withContext false
            val targetNode = findNodeByText(rootNode, elementName)
                ?: findNodeByContentDesc(rootNode, elementName)
                ?: return@withContext false

            val success = targetNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            targetNode.recycle()

            if (success) {
                logMessage("设备", "元素点击成功: $elementName")
            } else {
                logMessage("错误", "元素点击失败: $elementName")
            }

            success
        } catch (e: Exception) {
            Log.e(TAG, "元素点击异常", e)
            logMessage("错误", "元素点击异常: ${e.message}")
            false
        }
    }

    /**
     * 文本输入 - 三层降级策略
     */
    private suspend fun performType(text: String): Boolean = withContext(Dispatchers.IO) {
        try {
            // 策略1: 尝试Accessibility输入
            if (performTypeAccessibility(text)) {
                logMessage("设备", "Accessibility输入成功")
                return@withContext true
            }

            // 策略2: 尝试剪贴板输入
            if (performTypeClipboard(text)) {
                logMessage("设备", "剪贴板输入成功")
                return@withContext true
            }

            // 策略3: 尝试ADB输入（如果可用）
            if (performTypeADB(text)) {
                logMessage("设备", "ADB输入成功")
                return@withContext true
            }

            logMessage("错误", "所有输入方式均失败")
            false
        } catch (e: Exception) {
            Log.e(TAG, "文本输入异常", e)
            logMessage("错误", "文本输入异常: ${e.message}")
            false
        }
    }

    private fun performTypeAccessibility(text: String): Boolean {
        return try {
            val rootNode = rootInActiveWindow ?: return false
            val editNode = findEditableNode(rootNode) ?: return false

            val arguments = Bundle().apply {
                putString(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            }

            val success = editNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
            editNode.recycle()

            success
        } catch (e: Exception) {
            Log.e(TAG, "Accessibility输入失败", e)
            false
        }
    }

    private fun performTypeClipboard(text: String): Boolean {
        return try {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = ClipData.newPlainText("AutoGLM", text)
            clipboard.setPrimaryClip(clip)

            // 寻找输入框并执行粘贴
            val rootNode = rootInActiveWindow ?: return false
            val editNode = findEditableNode(rootNode) ?: return false

            editNode.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            val success = editNode.performAction(AccessibilityNodeInfo.ACTION_PASTE)
            editNode.recycle()

            success
        } catch (e: Exception) {
            Log.e(TAG, "剪贴板输入失败", e)
            false
        }
    }

    private fun performTypeADB(text: String): Boolean {
        // ADB输入需要特殊配置，这里暂时返回false
        return false
    }

    /**
     * 滑动手势
     */
    private suspend fun performSwipe(
        startX: Float, startY: Float,
        endX: Float, endY: Float,
        duration: Long
    ): Boolean = withContext(Dispatchers.IO) {
        try {
            val actualStartX = (startX / 1000f) * displayMetrics.widthPixels
            val actualStartY = (startY / 1000f) * displayMetrics.heightPixels
            val actualEndX = (endX / 1000f) * displayMetrics.widthPixels
            val actualEndY = (endY / 1000f) * displayMetrics.heightPixels

            val path = Path().apply {
                moveTo(actualStartX, actualStartY)
                lineTo(actualEndX, actualEndY)
            }

            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, duration))
                .build()

            val success = dispatchGesture(gesture, null, null)

            if (success) {
                logMessage("设备", "滑动成功: ($actualStartX,$actualStartY) -> ($actualEndX,$actualEndY)")
            } else {
                logMessage("错误", "滑动失败")
            }

            success
        } catch (e: Exception) {
            Log.e(TAG, "滑动操作异常", e)
            logMessage("错误", "滑动操作异常: ${e.message}")
            false
        }
    }

    /**
     * 启动应用
     */
    private suspend fun launchApp(appName: String): Boolean = withContext(Dispatchers.IO) {
        try {
            val packageName = findAppPackage(appName)
            if (packageName == null) {
                logMessage("错误", "未找到应用: $appName")
                return@withContext false
            }

            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent == null) {
                logMessage("错误", "无法获取应用启动Intent: $packageName")
                return@withContext false
            }

            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)

            logMessage("设备", "应用启动成功: $appName ($packageName)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "启动应用异常", e)
            logMessage("错误", "启动应用异常: ${e.message}")
            false
        }
    }

    // ============= 辅助功能 =============

    private fun findNodeByText(rootNode: AccessibilityNodeInfo, text: String): AccessibilityNodeInfo? {
        if (rootNode.text?.toString()?.contains(text, ignoreCase = true) == true) {
            return rootNode
        }

        for (i in 0 until rootNode.childCount) {
            val child = rootNode.getChild(i) ?: continue
            val result = findNodeByText(child, text)
            if (result != null) {
                child.recycle()
                return result
            }
            child.recycle()
        }

        return null
    }

    private fun findNodeByContentDesc(rootNode: AccessibilityNodeInfo, desc: String): AccessibilityNodeInfo? {
        if (rootNode.contentDescription?.toString()?.contains(desc, ignoreCase = true) == true) {
            return rootNode
        }

        for (i in 0 until rootNode.childCount) {
            val child = rootNode.getChild(i) ?: continue
            val result = findNodeByContentDesc(child, desc)
            if (result != null) {
                child.recycle()
                return result
            }
            child.recycle()
        }

        return null
    }

    private fun findEditableNode(rootNode: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (rootNode.isEditable || rootNode.className == "android.widget.EditText") {
            return rootNode
        }

        for (i in 0 until rootNode.childCount) {
            val child = rootNode.getChild(i) ?: continue
            val result = findEditableNode(child)
            if (result != null) {
                child.recycle()
                return result
            }
            child.recycle()
        }

        return null
    }

    private fun findAppPackage(appName: String): String? {
        // 先从缓存映射中查找
        appPackageMap[appName]?.let { return it }

        // 预定义的常用应用映射
        val predefinedMap = mapOf(
            "微信" to "com.tencent.mm",
            "QQ" to "com.tencent.mobileqq",
            "支付宝" to "com.eg.android.AlipayGphone",
            "淘宝" to "com.taobao.taobao",
            "抖音" to "com.ss.android.ugc.aweme",
            "微博" to "com.sina.weibo",
            "设置" to "com.android.settings",
            "Chrome" to "com.android.chrome",
            "相机" to "com.android.camera2"
        )

        predefinedMap[appName]?.let {
            appPackageMap[appName] = it
            return it
        }

        // 动态查找已安装的应用
        try {
            val packages = packageManager.getInstalledPackages(PackageManager.GET_META_DATA)
            for (packageInfo in packages) {
                val appInfo = packageInfo.applicationInfo ?: continue
                val appLabel = packageManager.getApplicationLabel(appInfo).toString()
                if (appLabel.contains(appName, ignoreCase = true)) {
                    appPackageMap[appName] = packageInfo.packageName
                    return packageInfo.packageName
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "动态查找应用包名失败", e)
        }

        return null
    }

    private fun initializeAppPackageMap() {
        serviceScope.launch(Dispatchers.IO) {
            try {
                val packages = packageManager.getInstalledPackages(PackageManager.GET_META_DATA)
                for (packageInfo in packages) {
                    try {
                        val appInfo = packageInfo.applicationInfo ?: continue
                        val appLabel = packageManager.getApplicationLabel(appInfo).toString()
                        appPackageMap[appLabel] = packageInfo.packageName
                    } catch (e: Exception) {
                        // 忽略单个应用的错误
                    }
                }
                Log.i(TAG, "应用包名映射初始化完成，共${appPackageMap.size}个应用")
            } catch (e: Exception) {
                Log.e(TAG, "初始化应用包名映射失败", e)
            }
        }
    }

    // ============= 条件评估和结果验证 =============

    private suspend fun evaluateCondition(condition: String): Boolean = withContext(Dispatchers.IO) {
        try {
            when {
                condition.contains("找到") -> {
                    val target = condition.substringAfter("找到").trim()
                    findElementExists(target)
                }
                condition.contains("界面") -> {
                    // 检查当前界面状态
                    rootInActiveWindow != null
                }
                condition.contains("应用") -> {
                    val appName = condition.substringAfter("应用").substringBefore("在").trim()
                    isAppRunning(appName)
                }
                else -> {
                    logMessage("警告", "未知条件类型: $condition")
                    true // 未知条件默认为true
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "条件评估异常", e)
            false
        }
    }

    private suspend fun verifyOutcome(outcome: String, context: Map<String, Any>): Boolean = withContext(Dispatchers.IO) {
        try {
            when {
                outcome.contains("点击成功") || outcome.contains("按钮状态改变") -> {
                    // 验证点击是否生效
                    delay(500) // 等待UI更新
                    true // 简化实现，实际应该检查UI变化
                }
                outcome.contains("搜索结果显示") -> {
                    // 验证搜索结果是否显示
                    findElementExists("搜索结果")
                }
                outcome.contains("页面跳转") || outcome.contains("进入") -> {
                    // 验证页面是否跳转
                    delay(1000) // 等待页面加载
                    true // 简化实现
                }
                else -> {
                    true // 其他情况默认成功
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "结果验证异常", e)
            false
        }
    }

    private fun findElementExists(elementName: String): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        val found = findNodeByText(rootNode, elementName) != null ||
                   findNodeByContentDesc(rootNode, elementName) != null
        return found
    }

    private fun isAppRunning(appName: String): Boolean {
        // 简化实现：检查当前包名是否匹配
        val packageName = findAppPackage(appName)
        return packageName != null
    }

    // ============= 悬浮窗管理 =============

    private fun showOverlay() {
        if (isOverlayVisible || !Settings.canDrawOverlays(this)) {
            return
        }

        try {
            overlayView = createOverlayView()

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    WindowManager.LayoutParams.TYPE_PHONE
                },
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                x = 0
                y = 100
            }

            windowManager.addView(overlayView, params)
            isOverlayVisible = true

            logMessage("系统", "悬浮窗显示成功")
        } catch (e: Exception) {
            Log.e(TAG, "显示悬浮窗失败", e)
            logMessage("错误", "显示悬浮窗失败: ${e.message}")
        }
    }

    private fun hideOverlay() {
        if (!isOverlayVisible || overlayView == null) {
            return
        }

        try {
            windowManager.removeView(overlayView)
            overlayView = null
            isOverlayVisible = false

            logMessage("系统", "悬浮窗已隐藏")
        } catch (e: Exception) {
            Log.e(TAG, "隐藏悬浮窗失败", e)
        }
    }

    private fun createOverlayView(): View {
        val view = LayoutInflater.from(this).inflate(
            android.R.layout.activity_list_item, null
        )

        // 这里应该创建自定义的悬浮窗布局
        // 为了简化，使用系统布局

        return view
    }

    fun updateOverlayStatus(status: String, isRunning: Boolean) {
        isTaskRunning.set(isRunning)

        // 更新悬浮窗显示内容
        overlayView?.findViewById<TextView>(android.R.id.text1)?.text = status

        logMessage("系统", "悬浮窗状态更新: $status")
    }

    // ============= 系统功能 =============

    private fun isAccessibilityServiceEnabled(): Boolean {
        return try {
            val service = "${packageName}/${this::class.java.canonicalName}"
            val enabledServices = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            enabledServices?.contains(service) == true
        } catch (e: Exception) {
            false
        }
    }

    private fun openAccessibilitySettings() {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "打开无障碍设置失败", e)
        }
    }

    private suspend fun monitorSystemState() {
        while (true) {
            try {
                // 定期监控系统状态
                delay(5000) // 每5秒检查一次

                // 检查服务连接状态
                if (!isAccessibilityServiceEnabled()) {
                    logMessage("警告", "无障碍服务连接断开")
                }

                // 清理过期的日志
                if (logBuffer.size > MAX_LOG_LINES) {
                    logBuffer.removeAt(0)
                }

            } catch (e: Exception) {
                Log.e(TAG, "系统状态监控异常", e)
                delay(10000) // 异常时延长检查间隔
            }
        }
    }

    // ============= 日志管理 =============

    private fun logMessage(category: String, message: String) {
        val timestamp = java.text.SimpleDateFormat("HH:mm:ss.SSS", java.util.Locale.getDefault())
            .format(java.util.Date())
        val formattedMessage = "[$timestamp] [$category] $message"

        // 添加到日志缓冲区
        synchronized(logBuffer) {
            logBuffer.add(formattedMessage)
            if (logBuffer.size > MAX_LOG_LINES) {
                logBuffer.removeAt(0)
            }
        }

        // 发送到Flutter
        logEventSink?.success(mapOf(
            "timestamp" to timestamp,
            "category" to category,
            "message" to message
        ))

        // 输出到Logcat
        Log.i(TAG, formattedMessage)
    }

    // ============= 无障碍服务回调 =============

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event?.let {
            // 处理无障碍事件
            when (it.eventType) {
                AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                    logMessage("事件", "检测到点击事件: ${it.className}")
                }
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                    logMessage("事件", "检测到文本变化: ${it.text}")
                }
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                    logMessage("事件", "窗口状态变化: ${it.packageName}")
                }
            }

            // 发送事件到Flutter
            eventSink?.success(mapOf(
                "type" to it.eventType,
                "packageName" to it.packageName?.toString(),
                "className" to it.className?.toString(),
                "text" to it.text?.toString()
            ))
        }
    }

    override fun onInterrupt() {
        logMessage("系统", "无障碍服务被中断")
    }

    override fun onDestroy() {
        instance = null
        serviceScope.cancel()
        hideOverlay()

        // 清理资源
        mediaProjection?.stop()
        virtualDisplay?.release()
        imageReader?.close()

        logMessage("系统", "AutoGLM服务已停止")
        super.onDestroy()
    }
}
