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
import android.content.ClipData
import android.content.ClipboardManager
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
    private var miniIconView: View? = null  // 最小化图标
    private var expandedView: View? = null  // 展开的窗口
    private var logTextView: TextView? = null
    private var isExpanded = false // 默认为最小化状态
    private val logBuffer = mutableListOf<String>() // 日志缓冲区
    private val maxLogLines = 50 // 最多显示50条日志
    private var overlayParams: WindowManager.LayoutParams? = null
    private val iconSize = 60 // dp
    
    // 记住小图标的位置
    private var savedIconX = -1
    private var savedIconY = -1

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

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }

    fun showOverlay() {
        if (overlayView != null) return
        
        createMiniIcon()
        logBuffer.clear()
        logBuffer.add("🤖 AutoGLM 已启动")
    }
    
    // 创建最小化的圆形图标
    private fun createMiniIcon() {
        val iconSizePx = dpToPx(iconSize)
        
        // 创建圆形图标容器
        val iconContainer = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(iconSizePx, iconSizePx)
        }
        
        // 圆形背景
        val iconBackground = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(iconSizePx, iconSizePx)
            // setBackgroundColor(Color.parseColor("#FF6B35")) // Removed solid color
            // 设置圆形shape - 半透明黑
            background = android.graphics.drawable.GradientDrawable().apply {
                shape = android.graphics.drawable.GradientDrawable.OVAL
                setColor(Color.parseColor("#99000000")) // 半透明黑
                setStroke(dpToPx(1), Color.WHITE) // 细白边
            }
        }
        
        // 图标文本
        val iconText = TextView(this).apply {
            text = "🤖"
            textSize = 24f
            gravity = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        
        iconContainer.addView(iconBackground)
        iconContainer.addView(iconText)
        
        miniIconView = iconContainer
        overlayView = miniIconView
        
        // 窗口参数 - 小图标
        val screenWidth = resources.displayMetrics.widthPixels
        val screenHeight = resources.displayMetrics.heightPixels
        
        overlayParams = WindowManager.LayoutParams(
            iconSizePx,
            iconSizePx,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) 
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY 
            else 
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or 
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or 
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            // 如果有保存的位置，恢复到保存的位置，否则使用默认位置
            if (savedIconX >= 0 && savedIconY >= 0) {
                x = savedIconX
                y = savedIconY
            } else {
                x = screenWidth - iconSizePx - dpToPx(10) // 初始位置：右边缘
                y = screenHeight / 2 // 初始位置：屏幕中间
            }
        }
        
        // 拖动和点击逻辑
        setupMiniIconTouchListener()
        
        try {
            windowManager?.addView(overlayView, overlayParams)
        } catch (e: Exception) {
            println("❌ Error adding mini icon: $e")
        }
    }
    
    // 设置小图标的触摸监听
    private fun setupMiniIconTouchListener() {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var hasMoved = false
        
        miniIconView?.setOnTouchListener { _, event ->
            when (event.action) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    initialX = overlayParams!!.x
                    initialY = overlayParams!!.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    hasMoved = false
                    true
                }
                android.view.MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = event.rawY - initialTouchY
                    
                    if (Math.abs(deltaX) > 10 || Math.abs(deltaY) > 10) {
                        hasMoved = true
                    }
                    
                    if (hasMoved) {
                        overlayParams!!.x = initialX + deltaX.toInt()
                        overlayParams!!.y = initialY + deltaY.toInt()
                        windowManager?.updateViewLayout(overlayView, overlayParams)
                    }
                    true
                }
                android.view.MotionEvent.ACTION_UP -> {
                    if (!hasMoved) {
                        // 点击：展开窗口
                        expandWindow()
                    } else {
                        // 拖动结束：吸附到边缘
                        snapToEdge()
                    }
                    true
                }
                else -> false
            }
        }
    }
    
    // 吸附到屏幕边缘
    private fun snapToEdge() {
        val screenWidth = resources.displayMetrics.widthPixels
        val currentX = overlayParams!!.x
        val iconSizePx = dpToPx(iconSize)
        
        // 判断靠近左边还是右边
        val targetX = if (currentX < screenWidth / 2) {
            -iconSizePx / 2 // 左边，隐藏一半
        } else {
            screenWidth - iconSizePx / 2 // 右边，隐藏一半
        }
        
        // 动画移动到边缘
        android.animation.ValueAnimator.ofInt(currentX, targetX).apply {
            duration = 200
            addUpdateListener { animator ->
                overlayParams!!.x = animator.animatedValue as Int
                windowManager?.updateViewLayout(overlayView, overlayParams)
            }
            start()
        }
    }
    
    // 展开窗口
    private fun expandWindow() {
        isExpanded = true
        
        // 保存小图标当前位置
        savedIconX = overlayParams?.x ?: -1
        savedIconY = overlayParams?.y ?: -1
        
        // 移除小图标
        try {
            windowManager?.removeView(miniIconView)
        } catch (e: Exception) {}
        
        // 创建展开的窗口
        createExpandedWindow()
    }
    
    // 创建展开的日志窗口
    private fun createExpandedWindow() {
        val container = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            // HUD 风格：深色半透明背景，圆角
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#99000000")) // 半透明黑
                cornerRadius = dpToPx(12).toFloat()
            }
            setPadding(0, 0, 0, 0)
        }
        
        // 标题栏
        val titleBar = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.HORIZONTAL
            setBackgroundColor(Color.TRANSPARENT) // 透明
            setPadding(dpToPx(16), dpToPx(8), dpToPx(16), dpToPx(8))
            gravity = Gravity.CENTER_VERTICAL
        }
        
        val titleText = TextView(this).apply {
            text = "🤖 AutoGLM"
            textSize = 12f
            setTextColor(Color.WHITE)
            layoutParams = android.widget.LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f
            )
        }
        
        // 缩小按钮 (变成一个小横线或V)
        val minimizeButton = TextView(this).apply {
            text = "－"
            textSize = 18f
            setTextColor(Color.WHITE)
            setPadding(dpToPx(8), 0, dpToPx(8), 0)
            setOnClickListener {
                minimizeWindow()
            }
        }
        
        // 移除关闭按钮，防止AI误触
        /*
        val closeButton = TextView(this).apply {
            text = "✕"
            textSize = 18f
            setTextColor(Color.WHITE)
            setPadding(dpToPx(8), 0, 0, 0)
            setOnClickListener {
                removeOverlay()
            }
        }
        */
        
        titleBar.addView(titleText)
        titleBar.addView(minimizeButton)
        // titleBar.addView(closeButton) // Removed
        
        // 日志文本区域（使用 ScrollView 包裹）
        val scrollView = android.widget.ScrollView(this).apply {
            layoutParams = android.widget.LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dpToPx(200) // 减小高度，避免遮挡太多
            )
        }
        
        logTextView = TextView(this).apply {
            text = logBuffer.joinToString("\n")
            textSize = 10f
            setTextColor(Color.parseColor("#E0E0E0"))
            setBackgroundColor(Color.TRANSPARENT)
            setPadding(dpToPx(12), dpToPx(12), dpToPx(12), dpToPx(12))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        
        scrollView.addView(logTextView)
        container.addView(titleBar)
        container.addView(scrollView)
        
        expandedView = container
        overlayView = expandedView
        
        // 展开窗口的窗口参数
        val screenWidth = resources.displayMetrics.widthPixels
        val screenHeight = resources.displayMetrics.heightPixels
        val windowWidth = (screenWidth * 0.85).toInt()
        
        overlayParams = WindowManager.LayoutParams(
            windowWidth,
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
            gravity = Gravity.TOP or Gravity.START
            x = (screenWidth - windowWidth) / 2 // 居中
            y = screenHeight / 2 - dpToPx(200) // 垂直居中偏上
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

    // 缩小窗口回到小图标
    private fun minimizeWindow() {
        isExpanded = false
        
        // 缩小动画（如果展开的窗口存在）
        expandedView?.animate()
            ?.scaleX(0.3f)
            ?.scaleY(0.3f)
            ?.alpha(0f)
            ?.setDuration(200)
            ?.withEndAction {
                try {
                    windowManager?.removeView(expandedView)
                } catch (e: Exception) {}
                
                // 显示小图标
                createMiniIcon()
            }
            ?.start()
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

    // 执行文本输入（使用 ADB Keyboard）
    fun performType(text: String) {
        println("⌨️ [AutoGLM] Typing text: $text")
        
        // 1. 尝试自动切换到 ADB Keyboard
        val originalIme = switchToAdbKeyboard()
        
        try {
            // 方法1：使用 ADB Keyboard（推荐，支持中文）
            val encodedText = android.util.Base64.encodeToString(
                text.toByteArray(Charsets.UTF_8),
                android.util.Base64.NO_WRAP
            )
            
            println("📝 [AutoGLM] Encoded text (base64): $encodedText")
            
            // 发送广播到 ADB Keyboard
            val intent = android.content.Intent().apply {
                action = "ADB_INPUT_B64"
                putExtra("msg", encodedText)
            }
            sendBroadcast(intent)
            
            println("✅ [AutoGLM] Broadcast sent to ADB Keyboard")
            
            // 等待输入完成
            Thread.sleep(1000) //稍微多等一会，给切换输入法和处理广播留时间
            
        } catch (e: Exception) {
            println("❌ [AutoGLM] ADB Keyboard input failed: ${e.message}")
            println("⚠️ [AutoGLM] Trying fallback method...")
            
            // 方法2：尝试使用 Accessibility Service 直接设置文本（备用）
            try {
                val rootNode = rootInActiveWindow
                if (rootNode != null) {
                    val focusedNode = rootNode.findFocus(android.view.accessibility.AccessibilityNodeInfo.FOCUS_INPUT)
                    if (focusedNode != null) {
                        val arguments = android.os.Bundle()
                        arguments.putCharSequence(
                            android.view.accessibility.AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                            text
                        )
                        val success = focusedNode.performAction(
                            android.view.accessibility.AccessibilityNodeInfo.ACTION_SET_TEXT,
                            arguments
                        )
                        focusedNode.recycle()
                        rootNode.recycle()
                        
                        if (success) {
                            println("✅ [AutoGLM] Fallback: Text set using ACTION_SET_TEXT")
                            // 即使备用方法成功，也要记得恢复输入法（虽然备用方法不依赖输入法，但前面可能已经切换了）
                            restoreKeyboard(originalIme)
                            return
                        }
                    }
                    rootNode.recycle()
                }
                
                // 如果 SET_TEXT 失败，尝试方法3：复制粘贴 (Paste)
                println("⚠️ [AutoGLM] ACTION_SET_TEXT failed, trying Clipboard Paste...")
                try {
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    val clip = ClipData.newPlainText("AutoGLM Input", text)
                    clipboard.setPrimaryClip(clip)
                    
                    val rootNode2 = rootInActiveWindow
                    if (rootNode2 != null) {
                        val focusedNode = rootNode2.findFocus(android.view.accessibility.AccessibilityNodeInfo.FOCUS_INPUT)
                        if (focusedNode != null) {
                            val success = focusedNode.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_PASTE)
                            focusedNode.recycle()
                            
                            if (success) {
                                println("✅ [AutoGLM] Fallback: Text pasted using ACTION_PASTE")
                                // 粘贴后尝试恢复输入法（如果有切换过）
                                restoreKeyboard(originalIme)
                                rootNode2.recycle()
                                return
                            }
                        }
                        rootNode2.recycle()
                    }
                } catch (e3: Exception) {
                    println("❌ [AutoGLM] Paste failed: ${e3.message}")
                }
                
                println("❌ [AutoGLM] All text input methods failed")
            } catch (e2: Exception) {
                println("❌ [AutoGLM] Fallback also failed: ${e2.message}")
            }
        } finally {
            // 3. 无论成功失败，都尝试恢复原输入法
            restoreKeyboard(originalIme)
        }
    }
    
    // 清除输入框文本（使用 ADB Keyboard）
    fun clearText() {
        println("🗑️ [AutoGLM] Clearing text field")
        try {
            val intent = android.content.Intent().apply {
                action = "ADB_CLEAR_TEXT"
            }
            sendBroadcast(intent)
            println("✅ [AutoGLM] Clear text broadcast sent")
            Thread.sleep(200)
        } catch (e: Exception) {
            println("❌ [AutoGLM] Clear text failed: ${e.message}")
        }
    }
    
    // 切换到 ADB Keyboard
    fun switchToAdbKeyboard(): String? {
        println("⌨️ [AutoGLM] Switching to ADB Keyboard")
        try {
            // 获取当前输入法
            val currentIme = android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.DEFAULT_INPUT_METHOD
            )
            println("📱 [AutoGLM] Current IME: $currentIme")
            
            // 如果不是 ADB Keyboard，则切换
            if (currentIme != null && !currentIme.contains("com.android.adbkeyboard/.AdbIME")) {
                val process = Runtime.getRuntime().exec(
                    arrayOf("settings", "put", "secure", "default_input_method", "com.android.adbkeyboard/.AdbIME")
                )
                process.waitFor()
                println("✅ [AutoGLM] Switched to ADB Keyboard")
                
                // 预热 ADB Keyboard
                Thread.sleep(500)
                performType("")
                
                return currentIme
            }
            
            return currentIme
        } catch (e: Exception) {
            println("❌ [AutoGLM] Failed to switch keyboard: ${e.message}")
            return null
        }
    }
    
    // 恢复原输入法
    fun restoreKeyboard(ime: String?) {
        if (ime != null && ime.isNotEmpty()) {
            println("⌨️ [AutoGLM] Restoring keyboard: $ime")
            try {
                val process = Runtime.getRuntime().exec(
                    arrayOf("settings", "put", "secure", "default_input_method", ime)
                )
                process.waitFor()
                println("✅ [AutoGLM] Keyboard restored")
            } catch (e: Exception) {
                println("❌ [AutoGLM] Failed to restore keyboard: ${e.message}")
            }
        }
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

