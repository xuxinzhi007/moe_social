package com.example.moe_social

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.view.accessibility.AccessibilityEvent
import android.graphics.Bitmap
import android.view.Display
import android.util.Base64
import java.io.ByteArrayOutputStream
import android.os.Build
import androidx.annotation.RequiresApi
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.WindowManager
import android.widget.TextView
import android.graphics.Color
import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.util.DisplayMetrics

class AutoGLMAccessibilityService : AccessibilityService() {

    companion object {
        var instance: AutoGLMAccessibilityService? = null
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var logTextView: TextView? = null
    private var isExpanded = true // 是否展开
    private val logBuffer = mutableListOf<String>() // 日志缓冲区
    private val maxLogLines = 30 // 最多显示30条日志
    private var overlayParams: WindowManager.LayoutParams? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        println("AutoGLM Accessibility Service Connected!")
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        removeOverlay()
        instance = null
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 监听事件，暂不需要处理，但必须重写
    }

    override fun onInterrupt() {
        // 服务中断
    }

    // --- 悬浮窗相关 ---

    fun showOverlay() {
        if (overlayView != null) return
        
        // 创建一个容器
        val container = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#DD000000")) // 深色半透明背景
            setPadding(0, 0, 0, 0)
        }
        
        // 标题栏（可拖动、可点击折叠）
        val titleBar = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.HORIZONTAL
            setBackgroundColor(Color.parseColor("#FF6B35")) // 橙色标题栏
            setPadding(16, 12, 16, 12)
            gravity = Gravity.CENTER_VERTICAL
        }
        
        val titleText = TextView(this).apply {
            text = "🤖 AutoGLM"
            textSize = 14f
            setTextColor(Color.WHITE)
            layoutParams = android.widget.LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f
            )
        }
        
        val toggleButton = TextView(this).apply {
            text = "▼"
            textSize = 16f
            setTextColor(Color.WHITE)
            setPadding(8, 0, 8, 0)
            isClickable = true
            isFocusable = false
        }
        
        // 折叠按钮的独立点击事件
        toggleButton.setOnTouchListener { _, event ->
            when (event.action) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    toggleButton.alpha = 0.6f
                    true
                }
                android.view.MotionEvent.ACTION_UP -> {
                    toggleButton.alpha = 1f
                    isExpanded = !isExpanded
                    if (isExpanded) {
                        logTextView?.visibility = View.VISIBLE
                        toggleButton.text = "▼"
                    } else {
                        logTextView?.visibility = View.GONE
                        toggleButton.text = "▲"
                    }
                    true
                }
                android.view.MotionEvent.ACTION_CANCEL -> {
                    toggleButton.alpha = 1f
                    true
                }
                else -> true
            }
        }
        
        val closeButton = TextView(this).apply {
            text = "✕"
            textSize = 18f
            setTextColor(Color.WHITE)
            setPadding(8, 0, 0, 0)
            isClickable = true
            isFocusable = false
        }
        
        // 关闭按钮的独立点击事件（消费所有触摸事件，防止被拖动逻辑干扰）
        closeButton.setOnTouchListener { _, event ->
            when (event.action) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    // 高亮效果
                    closeButton.alpha = 0.6f
                    true
                }
                android.view.MotionEvent.ACTION_UP -> {
                    closeButton.alpha = 1f
                    removeOverlay()
                    true
                }
                android.view.MotionEvent.ACTION_CANCEL -> {
                    closeButton.alpha = 1f
                    true
                }
                else -> true // 消费所有事件
            }
        }
        
        titleBar.addView(titleText)
        titleBar.addView(toggleButton)
        titleBar.addView(closeButton)
        
        // 日志文本区域
        logTextView = TextView(this).apply {
            text = "等待任务..."
            textSize = 11f
            setTextColor(Color.parseColor("#E0E0E0"))
            setBackgroundColor(Color.TRANSPARENT)
            setPadding(16, 12, 16, 12)
            maxLines = 20
            layoutParams = android.widget.LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            movementMethod = android.text.method.ScrollingMovementMethod()
            isVerticalScrollBarEnabled = true
        }
        
        container.addView(titleBar)
        container.addView(logTextView)
        
        overlayView = container
        
        // 窗口参数 - 使用绝对坐标定位
        val screenWidth = resources.displayMetrics.widthPixels
        val screenHeight = resources.displayMetrics.heightPixels
        val windowWidth = (screenWidth * 0.9).toInt()
        
        overlayParams = WindowManager.LayoutParams(
            windowWidth, // 90% 屏幕宽度
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) 
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY 
            else 
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or 
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or 
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START // 使用左上角作为参考点
            x = (screenWidth - windowWidth) / 2 // 初始位置：水平居中
            y = screenHeight - 600 // 初始位置：距离底部600像素
        }
        
        // 标题栏拖动和点击功能
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isDragging = false
        var hasMoved = false
        
        titleBar.setOnTouchListener { view, event ->
            when (event.action) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    initialX = overlayParams!!.x
                    initialY = overlayParams!!.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    hasMoved = false
                    true
                }
                android.view.MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = event.rawY - initialTouchY
                    
                    // 如果移动距离超过10像素，认为是拖动
                    if (Math.abs(deltaX) > 10 || Math.abs(deltaY) > 10) {
                        isDragging = true
                        hasMoved = true
                    }
                    
                    if (isDragging) {
                        // 使用 TOP|START 坐标系：x/y 增加表示向右/下移动
                        overlayParams!!.x = initialX + deltaX.toInt()
                        overlayParams!!.y = initialY + deltaY.toInt()
                        
                        // 限制在屏幕范围内
                        val screenWidth = resources.displayMetrics.widthPixels
                        val screenHeight = resources.displayMetrics.heightPixels
                        val windowWidth = overlayParams!!.width
                        
                        overlayParams!!.x = overlayParams!!.x.coerceIn(0, screenWidth - windowWidth)
                        overlayParams!!.y = overlayParams!!.y.coerceIn(0, screenHeight - 200) // 留出底部空间
                        
                        windowManager?.updateViewLayout(overlayView, overlayParams)
                    }
                    true
                }
                android.view.MotionEvent.ACTION_UP -> {
                    // 拖动结束
                    isDragging = false
                    true
                }
                else -> false
            }
        }

        try {
            windowManager?.addView(overlayView, overlayParams)
            logBuffer.clear()
            logBuffer.add("🤖 AutoGLM 已启动")
        } catch (e: Exception) {
            println("❌ Error adding overlay view: $e")
        }
    }

    fun updateOverlayLog(log: String) {
        // 在主线程更新UI
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        handler.post {
            if (overlayView == null) showOverlay()
            
            // 添加新日志到缓冲区
            logBuffer.add(log)
            
            // 如果超过最大行数，移除最早的日志
            if (logBuffer.size > maxLogLines) {
                logBuffer.removeAt(0)
            }
            
            // 更新显示
            val displayText = logBuffer.joinToString("\n")
            logTextView?.text = displayText
            
            // 自动滚动到底部
            logTextView?.post {
                val layout = logTextView?.layout
                if (layout != null && logTextView!!.lineCount > 0) {
                    val scrollAmount = layout.getLineTop(logTextView!!.lineCount) - logTextView!!.height
                    if (scrollAmount > 0) {
                        logTextView?.scrollTo(0, scrollAmount)
                    }
                }
            }
        }
    }

    fun removeOverlay() {
        if (overlayView != null) {
            try {
                windowManager?.removeView(overlayView)
            } catch (e: Exception) {
                // ignore
            }
            overlayView = null
        }
    }

    // --- 动作执行 (使用相对坐标 0-1000) ---

    private fun getScreenMetrics(): DisplayMetrics {
        val metrics = DisplayMetrics()
        windowManager?.defaultDisplay?.getRealMetrics(metrics)
        return metrics
    }

    // 执行点击 (输入为相对坐标 0-1000)
    fun performClick(relX: Float, relY: Float) {
        val metrics = getScreenMetrics()
        val x = (relX / 1000f) * metrics.widthPixels
        val y = (relY / 1000f) * metrics.heightPixels
        
        println("🎯 [AutoGLM] Performing click at: ($x, $y) pixels, from relative ($relX, $relY), screen: ${metrics.widthPixels}x${metrics.heightPixels}")

        val path = Path()
        path.moveTo(x, y)
        path.lineTo(x, y) // Ensure it's a point
        val builder = GestureDescription.Builder()
        builder.addStroke(GestureDescription.StrokeDescription(path, 0, 100))
        
        val success = dispatchGesture(builder.build(), object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                println("✅ [AutoGLM] Click gesture completed")
            }
            override fun onCancelled(gestureDescription: GestureDescription?) {
                println("❌ [AutoGLM] Click gesture cancelled")
            }
        }, null)
        
        if (!success) {
            println("❌ [AutoGLM] Failed to dispatch click gesture")
        }
    }

    // 执行滑动 (输入为相对坐标 0-1000)
    fun performSwipe(relX1: Float, relY1: Float, relX2: Float, relY2: Float, duration: Long) {
        val metrics = getScreenMetrics()
        val x1 = (relX1 / 1000f) * metrics.widthPixels
        val y1 = (relY1 / 1000f) * metrics.heightPixels
        val x2 = (relX2 / 1000f) * metrics.widthPixels
        val y2 = (relY2 / 1000f) * metrics.heightPixels

        println("👆 [AutoGLM] Performing swipe from ($x1, $y1) to ($x2, $y2) pixels, duration ${duration}ms")

        val path = Path()
        path.moveTo(x1, y1)
        path.lineTo(x2, y2)
        val builder = GestureDescription.Builder()
        builder.addStroke(GestureDescription.StrokeDescription(path, 0, duration))
        
        val success = dispatchGesture(builder.build(), object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                println("✅ [AutoGLM] Swipe gesture completed")
            }
            override fun onCancelled(gestureDescription: GestureDescription?) {
                println("❌ [AutoGLM] Swipe gesture cancelled")
            }
        }, null)
        
        if (!success) {
            println("❌ [AutoGLM] Failed to dispatch swipe gesture")
        }
    }

    // 执行返回
    fun performBack() {
        println("⬅️ [AutoGLM] Performing Global Back")
        val success = performGlobalAction(GLOBAL_ACTION_BACK)
        println(if (success) "✅ [AutoGLM] Back action completed" else "❌ [AutoGLM] Back action failed")
    }

    // 执行Home
    fun performHome() {
        println("🏠 [AutoGLM] Performing Global Home")
        val success = performGlobalAction(GLOBAL_ACTION_HOME)
        println(if (success) "✅ [AutoGLM] Home action completed" else "❌ [AutoGLM] Home action failed")
    }

    // 获取已安装的应用列表
    fun getInstalledApps(): Map<String, String> {
        val installedApps = mutableMapOf<String, String>()
        try {
            val pm = packageManager
            val packages = pm.getInstalledApplications(android.content.pm.PackageManager.GET_META_DATA)
            
            for (packageInfo in packages) {
                // 只获取有启动 Activity 的应用
                val launchIntent = pm.getLaunchIntentForPackage(packageInfo.packageName)
                if (launchIntent != null) {
                    val appName = pm.getApplicationLabel(packageInfo).toString()
                    installedApps[appName] = packageInfo.packageName
                }
            }
            
            println("📱 [AutoGLM] Found ${installedApps.size} installed apps")
        } catch (e: Exception) {
            println("❌ [AutoGLM] Error getting installed apps: ${e.message}")
        }
        return installedApps
    }

    // 启动应用（优先使用动态读取的包名，再回退到预定义列表）
    fun launchApp(appName: String): Boolean {
        println("🚀 [AutoGLM] Attempting to launch app: $appName")
        
        // 先尝试从已安装应用中查找
        val installedApps = getInstalledApps()
        var packageName = installedApps[appName]
        
        // 如果没找到，尝试从预定义列表查找
        if (packageName == null) {
            packageName = AppPackages.getPackageName(appName)
        }
        
        if (packageName == null) {
            println("❌ [AutoGLM] App package not found for: $appName")
            println("💡 [AutoGLM] Installed apps: ${installedApps.keys.take(10)}")
            return false
        }

        println("📦 [AutoGLM] Package name: $packageName")
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                println("✅ [AutoGLM] Successfully launched app: $appName ($packageName)")
                return true
            } else {
                println("❌ [AutoGLM] No launch intent found for: $packageName (app might not be installed)")
                return false
            }
        } catch (e: Exception) {
            println("❌ [AutoGLM] Error launching app $appName: ${e.message}")
            e.printStackTrace()
            return false
        }
    }

    // ... existing code ...
    @RequiresApi(Build.VERSION_CODES.R)
    fun takeScreenShot(callback: (String?) -> Unit) {
        takeScreenshot(Display.DEFAULT_DISPLAY, mainExecutor, object : TakeScreenshotCallback {
            override fun onSuccess(result: ScreenshotResult) {
                val bitmap = Bitmap.wrapHardwareBuffer(result.hardwareBuffer, result.colorSpace)
                if (bitmap != null) {
                    val stream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 70, stream)
                    val byteArray = stream.toByteArray()
                    val base64String = Base64.encodeToString(byteArray, Base64.NO_WRAP)
                    callback(base64String)
                    // bitmap.recycle() // wrapHardwareBuffer产生的bitmap不需要显式recycle，或者由GC处理
                } else {
                    callback(null)
                }
                result.hardwareBuffer.close()
            }

            override fun onFailure(errorCode: Int) {
                println("Screenshot failed: $errorCode")
                callback(null)
            }
        })
    }
}

