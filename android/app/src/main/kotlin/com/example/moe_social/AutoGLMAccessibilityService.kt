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
import android.util.Log

class AutoGLMAccessibilityService : AccessibilityService() {

    companion object {
        var instance: AutoGLMAccessibilityService? = null
        var logListener: ((String) -> Unit)? = null
    }
    
    private fun log(msg: String) {
        // Logcat 更稳定（flutter run/安卓日志更容易看到），System.out 用作兜底
        Log.i("AutoGLM", msg)
        System.out.println(msg)
        try {
            logListener?.invoke(msg)
        } catch (e: Exception) {
            // ignore
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var miniIconView: View? = null  // 最小化状态条
    private var expandedView: View? = null  // 展开的窗口
    private var logTextView: TextView? = null
    private var statusTextView: TextView? = null  // 状态栏文字
    private var progressIndicator: View? = null   // 进度指示器
    private var isExpanded = false // 默认为最小化状态
    private val logBuffer = mutableListOf<String>() // 日志缓冲区
    private val maxLogLines = 50 // 最多显示50条日志
    private var overlayParams: WindowManager.LayoutParams? = null
    private val statusBarHeight = 28 // dp - 状态条高度
    private val statusBarWidth = 180 // dp - 状态条宽度
    
    // 记住状态条的位置
    private var savedIconX = -1
    private var savedIconY = -1
    
    // 当前任务状态
    private var currentStep = 0
    private var maxSteps = 20
    private var isTaskRunning = false
    private var currentStatus = "就绪"
    
    // 输入法会话管理
    private var sessionOriginalIme: String? = null

    // --- 日志气泡 (Tooltip) 相关变量 ---
    private var tooltipView: View? = null
    private var tooltipParams: WindowManager.LayoutParams? = null
    private val tooltipHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private val hideTooltipRunnable = Runnable { removeTooltip() }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        log("AutoGLM Accessibility Service Connected!")
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
    
    // 创建最小化的系统状态条（类似系统通知，不像广告弹窗）
    private fun createMiniIcon() {
        val barWidth = dpToPx(statusBarWidth)
        val barHeight = dpToPx(statusBarHeight)
        
        // 创建水平布局的状态条
        val statusBar = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            // 系统风格：深灰半透明 + 圆角（类似 Android 系统弹窗）
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#E0303030")) // 深灰色，高不透明度（系统风格）
                cornerRadius = dpToPx(14).toFloat() // 圆角胶囊
                setStroke(dpToPx(1), Color.parseColor("#505050")) // 灰色边框
            }
            setPadding(dpToPx(10), dpToPx(4), dpToPx(10), dpToPx(4))
        }
        
        // 系统服务图标（使用系统图标风格，不用 emoji）
        val iconView = TextView(this).apply {
            text = "⚙" // 齿轮图标 - 系统服务风格
            textSize = 14f
            setTextColor(Color.parseColor("#4FC3F7")) // 浅蓝色 - 系统强调色
            setPadding(0, 0, dpToPx(6), 0)
        }
        
        // 状态文字
        statusTextView = TextView(this).apply {
            text = currentStatus
            textSize = 11f
            setTextColor(Color.WHITE)
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            layoutParams = android.widget.LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f
            )
        }
        
        // 进度点指示器（动画效果）
        progressIndicator = View(this).apply {
            layoutParams = android.widget.LinearLayout.LayoutParams(dpToPx(8), dpToPx(8)).apply {
                marginStart = dpToPx(6)
            }
            background = android.graphics.drawable.GradientDrawable().apply {
                shape = android.graphics.drawable.GradientDrawable.OVAL
                setColor(if (isTaskRunning) Color.parseColor("#4CAF50") else Color.parseColor("#9E9E9E"))
            }
        }
        
        // 停止按钮（红色 X，长按停止）
        val stopButton = TextView(this).apply {
            text = "×"
            textSize = 16f
            setTextColor(Color.parseColor("#FF5252")) // 红色
            setPadding(dpToPx(8), 0, 0, 0)
            setOnClickListener {
                // 单击停止任务
                if (isTaskRunning) {
                    stopTaskCallback?.invoke()
                    updateStatus("已停止", false)
                }
            }
        }
        
        statusBar.addView(iconView)
        statusBar.addView(statusTextView)
        statusBar.addView(progressIndicator)
        statusBar.addView(stopButton)
        
        miniIconView = statusBar
        overlayView = miniIconView
        
        // 窗口参数 - 状态条（固定在顶部中央，像系统通知）
        val screenWidth = resources.displayMetrics.widthPixels
        
        overlayParams = WindowManager.LayoutParams(
            barWidth,
            barHeight,
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
            // 固定在顶部中央（状态栏下方）- 系统通知风格
            if (savedIconX >= 0 && savedIconY >= 0) {
                x = savedIconX
                y = savedIconY
            } else {
                x = (screenWidth - barWidth) / 2 // 水平居中
                y = dpToPx(40) // 距顶部一点距离（状态栏下方）
            }
        }
        
        // 拖动和点击逻辑
        setupMiniIconTouchListener()
        
        // 如果任务正在运行，启动进度点动画
        if (isTaskRunning) {
            startProgressAnimation()
        }
        
        try {
            windowManager?.addView(overlayView, overlayParams)
        } catch (e: Exception) {
            log("❌ Error adding status bar: $e")
        }
    }
    
    // 进度点呼吸动画
    private fun startProgressAnimation() {
        progressIndicator?.animate()
            ?.alpha(0.3f)
            ?.setDuration(500)
            ?.withEndAction {
                progressIndicator?.animate()
                    ?.alpha(1f)
                    ?.setDuration(500)
                    ?.withEndAction {
                        if (isTaskRunning && progressIndicator?.parent != null) {
                            startProgressAnimation()
                        }
                    }
                    ?.start()
            }
            ?.start()
    }
    
    // 停止任务回调
    var stopTaskCallback: (() -> Unit)? = null
    
    // 更新状态显示
    fun updateStatus(status: String, running: Boolean) {
        currentStatus = status
        isTaskRunning = running
        
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        handler.post {
            statusTextView?.text = status
            
            // 更新进度点颜色
            (progressIndicator?.background as? android.graphics.drawable.GradientDrawable)?.setColor(
                if (running) Color.parseColor("#4CAF50") else Color.parseColor("#9E9E9E")
            )
            
            if (running && !isExpanded) {
                startProgressAnimation()
            }
        }
    }
    
    // 更新步骤进度
    fun updateProgress(step: Int, total: Int) {
        currentStep = step
        maxSteps = total
        updateStatus("步骤 $step/$total", true)
    }
    
    // 设置状态条的触摸监听
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
                    
                    if (Math.abs(deltaX) > 15 || Math.abs(deltaY) > 15) {
                        hasMoved = true
                    }
                    
                    if (hasMoved) {
                        overlayParams!!.x = initialX + deltaX.toInt()
                        overlayParams!!.y = initialY + deltaY.toInt()
                        
                        // 限制在屏幕范围内
                        val screenWidth = resources.displayMetrics.widthPixels
                        val screenHeight = resources.displayMetrics.heightPixels
                        val barWidth = dpToPx(statusBarWidth)
                        
                        overlayParams!!.x = overlayParams!!.x.coerceIn(0, screenWidth - barWidth)
                        overlayParams!!.y = overlayParams!!.y.coerceIn(0, screenHeight - dpToPx(60))
                        
                        windowManager?.updateViewLayout(overlayView, overlayParams)
                    }
                    true
                }
                android.view.MotionEvent.ACTION_UP -> {
                    if (!hasMoved) {
                        // 点击：展开日志窗口
                        expandWindow()
                    } else {
                        // 保存拖动后的位置
                        savedIconX = overlayParams!!.x
                        savedIconY = overlayParams!!.y
                    }
                    true
                }
                else -> false
            }
        }
    }
    
    // 展开窗口
    private fun expandWindow() {
        isExpanded = true
        
        // 保存状态条当前位置
        savedIconX = overlayParams?.x ?: -1
        savedIconY = overlayParams?.y ?: -1
        
        // 移除状态条
        try {
            windowManager?.removeView(miniIconView)
        } catch (e: Exception) {}
        
        miniIconView = null
        statusTextView = null
        progressIndicator = null
        
        // 创建展开的窗口
        createExpandedWindow()
    }
    
    // 创建展开的日志窗口（系统面板风格）
    private fun createExpandedWindow() {
        val container = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            // 系统面板风格：深灰背景，清晰边框
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#F0303030")) // 深灰色，高不透明度
                cornerRadius = dpToPx(16).toFloat()
                setStroke(dpToPx(1), Color.parseColor("#505050"))
            }
            setPadding(0, 0, 0, 0)
            elevation = dpToPx(8).toFloat() // 添加阴影
        }
        
        // 标题栏
        val titleBar = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.HORIZONTAL
            // 标题栏稍深一点
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#252525"))
                cornerRadii = floatArrayOf(
                    dpToPx(16).toFloat(), dpToPx(16).toFloat(), // 左上
                    dpToPx(16).toFloat(), dpToPx(16).toFloat(), // 右上
                    0f, 0f, 0f, 0f // 下方不圆角
                )
            }
            setPadding(dpToPx(14), dpToPx(10), dpToPx(14), dpToPx(10))
            gravity = Gravity.CENTER_VERTICAL
        }
        
        // 系统图标
        val iconView = TextView(this).apply {
            text = "⚙"
            textSize = 14f
            setTextColor(Color.parseColor("#4FC3F7"))
            setPadding(0, 0, dpToPx(8), 0)
        }
        
        val titleText = TextView(this).apply {
            text = "系统自动化服务"
            textSize = 13f
            setTextColor(Color.WHITE)
            layoutParams = android.widget.LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f
            )
        }
        
        // 状态标签
        val statusLabel = TextView(this).apply {
            text = if (isTaskRunning) "运行中" else "空闲"
            textSize = 10f
            setTextColor(if (isTaskRunning) Color.parseColor("#4CAF50") else Color.parseColor("#9E9E9E"))
            setPadding(dpToPx(8), dpToPx(2), dpToPx(8), dpToPx(2))
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#1A1A1A"))
                cornerRadius = dpToPx(8).toFloat()
            }
        }
        
        // 缩小按钮
        val minimizeButton = TextView(this).apply {
            text = "▼"
            textSize = 14f
            setTextColor(Color.parseColor("#AAAAAA"))
            setPadding(dpToPx(12), 0, 0, 0)
            setOnClickListener {
                minimizeWindow()
            }
        }
        
        titleBar.addView(iconView)
        titleBar.addView(titleText)
        titleBar.addView(statusLabel)
        titleBar.addView(minimizeButton)
        
        // 日志文本区域（使用 ScrollView 包裹）
        val scrollView = android.widget.ScrollView(this).apply {
            layoutParams = android.widget.LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dpToPx(180)
            )
            isVerticalScrollBarEnabled = true
        }
        
        logTextView = TextView(this).apply {
            text = logBuffer.joinToString("\n")
            textSize = 10f
            setTextColor(Color.parseColor("#CCCCCC"))
            setBackgroundColor(Color.TRANSPARENT)
            setPadding(dpToPx(12), dpToPx(8), dpToPx(12), dpToPx(8))
            typeface = android.graphics.Typeface.MONOSPACE // 等宽字体
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        
        // 底部操作栏
        val bottomBar = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.HORIZONTAL
            gravity = Gravity.END or Gravity.CENTER_VERTICAL
            setPadding(dpToPx(12), dpToPx(8), dpToPx(12), dpToPx(10))
        }
        
        // 停止按钮（仅在运行时显示）
        if (isTaskRunning) {
            val stopBtn = TextView(this).apply {
                text = "停止任务"
                textSize = 11f
                setTextColor(Color.parseColor("#FF5252"))
                setPadding(dpToPx(12), dpToPx(6), dpToPx(12), dpToPx(6))
                background = android.graphics.drawable.GradientDrawable().apply {
                    setColor(Color.parseColor("#3D1A1A"))
                    cornerRadius = dpToPx(12).toFloat()
                }
                setOnClickListener {
                    stopTaskCallback?.invoke()
                    updateStatus("已停止", false)
                }
            }
            bottomBar.addView(stopBtn)
        }
        
        scrollView.addView(logTextView)
        container.addView(titleBar)
        container.addView(scrollView)
        container.addView(bottomBar)
        
        expandedView = container
        overlayView = expandedView
        
        // 展开窗口的窗口参数
        val screenWidth = resources.displayMetrics.widthPixels
        val screenHeight = resources.displayMetrics.heightPixels
        val windowWidth = (screenWidth * 0.88).toInt()
        
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
            y = dpToPx(60) // 靠近顶部
        }
        
        // 标题栏拖动功能
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isDragging = false
        
        titleBar.setOnTouchListener { _, event ->
            when (event.action) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    initialX = overlayParams!!.x
                    initialY = overlayParams!!.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    true
                }
                android.view.MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = event.rawY - initialTouchY
                    
                    if (Math.abs(deltaX) > 10 || Math.abs(deltaY) > 10) {
                        isDragging = true
                    }
                    
                    if (isDragging) {
                        overlayParams!!.x = initialX + deltaX.toInt()
                        overlayParams!!.y = initialY + deltaY.toInt()
                        
                        // 限制在屏幕范围内
                        overlayParams!!.x = overlayParams!!.x.coerceIn(0, screenWidth - windowWidth)
                        overlayParams!!.y = overlayParams!!.y.coerceIn(0, screenHeight - dpToPx(250))
                        
                        windowManager?.updateViewLayout(overlayView, overlayParams)
                    }
                    true
                }
                android.view.MotionEvent.ACTION_UP -> {
                    isDragging = false
                    true
                }
                else -> false
            }
        }

        try {
            windowManager?.addView(overlayView, overlayParams)
            scrollToBottom()
        } catch (e: Exception) {
            log("❌ Error adding overlay view: $e")
        }
    }

    private fun scrollToBottom() {
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
            
            if (isExpanded) {
                // 如果是展开状态，更新大窗口的文本
                val displayText = logBuffer.joinToString("\n")
                logTextView?.text = displayText
                
                // 自动滚动到底部
                scrollToBottom()
            } else {
                // 如果是最小化状态，显示气泡提示
                showTooltip(log)
            }
        }
    }

    // --- 气泡提示 (Tooltip) 实现 ---

    private fun createTooltipView() {
        val container = FrameLayout(this).apply {
            // 深色半透明圆角背景
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#CC000000"))
                cornerRadius = dpToPx(8).toFloat()
            }
            setPadding(dpToPx(12), dpToPx(8), dpToPx(12), dpToPx(8))
        }
        
        val textView = TextView(this).apply {
            id = android.R.id.text1
            textSize = 13f
            setTextColor(Color.WHITE)
            maxWidth = dpToPx(220) // 限制最大宽度
        }
        container.addView(textView)
        
        tooltipView = container
        
        tooltipParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) 
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY 
            else 
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or 
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or // 关键：允许点击穿透！
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            windowAnimations = android.R.style.Animation_Toast // 淡入淡出动画
        }
    }

    private fun updateTooltipPosition() {
        if (overlayParams == null || tooltipParams == null) return
        
        val barX = overlayParams!!.x
        val barY = overlayParams!!.y
        val barHeightPx = dpToPx(statusBarHeight)
        val screenH = resources.displayMetrics.heightPixels
        
        // 简单智能定位：如果在屏幕下半部分，显示在上方；否则显示在下方
        if (barY > screenH / 2) {
            // 显示在上方 (预估气泡高度 50dp)
            tooltipParams!!.y = barY - dpToPx(50)
        } else {
            // 显示在下方
            tooltipParams!!.y = barY + barHeightPx + dpToPx(8)
        }
        
        // X轴对齐：与状态条左侧对齐
        tooltipParams!!.x = barX
    }

    private fun showTooltip(text: String) {
        // 移除之前的隐藏任务
        tooltipHandler.removeCallbacks(hideTooltipRunnable)
        
        if (tooltipView == null) createTooltipView()
        
        // 更新文本
        tooltipView?.findViewById<TextView>(android.R.id.text1)?.text = text
        
        // 更新位置
        updateTooltipPosition()
        
        // 添加到窗口
        if (tooltipView?.parent == null) {
            try {
                windowManager?.addView(tooltipView, tooltipParams)
            } catch (e: Exception) { e.printStackTrace() }
        } else {
            try {
                windowManager?.updateViewLayout(tooltipView, tooltipParams)
            } catch (e: Exception) {}
        }
        
        // 3秒后自动隐藏
        tooltipHandler.postDelayed(hideTooltipRunnable, 3000)
    }

    private fun removeTooltip() {
        if (tooltipView != null && tooltipView?.parent != null) {
            try {
                windowManager?.removeView(tooltipView)
            } catch (e: Exception) {}
        }
    }

    // 缩小窗口回到状态条
    private fun minimizeWindow() {
        isExpanded = false
        
        // 缩小动画
        expandedView?.animate()
            ?.scaleX(0.5f)
            ?.scaleY(0.5f)
            ?.alpha(0f)
            ?.setDuration(150)
            ?.withEndAction {
                try {
                    windowManager?.removeView(expandedView)
                } catch (e: Exception) {}
                
                expandedView = null
                logTextView = null
                
                // 显示状态条
                createMiniIcon()
            }
            ?.start()
    }

    fun removeOverlay() {
        removeTooltip() // 同时移除气泡
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
        
        log("🎯 点击坐标: (${"%.0f".format(x)}, ${"%.0f".format(y)}) 像素")

        val path = Path()
        path.moveTo(x, y)
        path.lineTo(x, y)
        val builder = GestureDescription.Builder()
        builder.addStroke(GestureDescription.StrokeDescription(path, 0, 100))
        
        val success = dispatchGesture(builder.build(), object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                log("✅ 点击完成")
            }
            override fun onCancelled(gestureDescription: GestureDescription?) {
                log("❌ 点击被取消")
            }
        }, null)
        
        if (!success) {
            log("❌ 点击手势执行失败")
        }
    }

    // 执行滑动 (输入为相对坐标 0-1000)
    fun performSwipe(relX1: Float, relY1: Float, relX2: Float, relY2: Float, duration: Long) {
        val metrics = getScreenMetrics()
        val x1 = (relX1 / 1000f) * metrics.widthPixels
        val y1 = (relY1 / 1000f) * metrics.heightPixels
        val x2 = (relX2 / 1000f) * metrics.widthPixels
        val y2 = (relY2 / 1000f) * metrics.heightPixels

        log("👆 滑动: (${"%.0f".format(x1)}, ${"%.0f".format(y1)}) → (${"%.0f".format(x2)}, ${"%.0f".format(y2)})")

        val path = Path()
        path.moveTo(x1, y1)
        path.lineTo(x2, y2)
        val builder = GestureDescription.Builder()
        builder.addStroke(GestureDescription.StrokeDescription(path, 0, duration))
        
        val success = dispatchGesture(builder.build(), object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                log("✅ 滑动完成")
            }
            override fun onCancelled(gestureDescription: GestureDescription?) {
                log("❌ 滑动被取消")
            }
        }, null)
        
        if (!success) {
            log("❌ 滑动手势执行失败")
        }
    }

    // 执行返回
    fun performBack() {
        log("⬅️ 执行返回")
        val success = performGlobalAction(GLOBAL_ACTION_BACK)
        log(if (success) "✅ 返回完成" else "❌ 返回失败")
    }

    // 执行Home
    fun performHome() {
        log("🏠 返回桌面")
        val success = performGlobalAction(GLOBAL_ACTION_HOME)
        log(if (success) "✅ 已返回桌面" else "❌ 返回桌面失败")
    }

    // 执行文本输入（支持多种方式）
    fun performType(text: String) {
        // 关键修复：将耗时操作移至子线程，防止阻塞主线程导致ANR
        Thread {
            log("⌨️ 输入文字: $text")
            
            var inputSuccess = false
            
            // 检查当前是否已经是 ADB Keyboard
            val currentIme = android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.DEFAULT_INPUT_METHOD
            )
            val isAdbKeyboard = currentIme?.contains("com.android.adbkeyboard/.AdbIME") == true
            
            // 方法1：如果当前是 ADB Keyboard，使用广播方式
            if (isAdbKeyboard) {
                try {
                    val encodedText = android.util.Base64.encodeToString(
                        text.toByteArray(Charsets.UTF_8),
                        android.util.Base64.NO_WRAP
                    )
                    
                    log("📝 使用 ADB Keyboard 输入")
                    
                    val intent = android.content.Intent().apply {
                        action = "ADB_INPUT_B64"
                        putExtra("msg", encodedText)
                    }
                    sendBroadcast(intent)
                    
                    Thread.sleep(1000)
                    log("✅ 文字已通过 ADB Keyboard 发送")
                    inputSuccess = true
                } catch (e: Exception) {
                    log("⚠️ ADB Keyboard 广播失败: ${e.message}")
                }
            } else {
                log("📱 当前输入法不是 ADB Keyboard，使用备用方式")
            }
            
            // 方法2：使用 Accessibility 直接设置文本（最可靠的备用方案）
            if (!inputSuccess) {
                log("🔄 尝试直接设置文本...")
                try {
                    val rootNode = rootInActiveWindow
                    if (rootNode != null) {
                        // 查找当前焦点的输入框
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
                            
                            if (success) {
                                log("✅ 文字已设置到输入框")
                                inputSuccess = true
                            } else {
                                log("⚠️ 设置文本返回失败")
                            }
                        } else {
                            log("⚠️ 未找到聚焦的输入框")
                            
                            // 尝试查找可编辑的节点
                            val editableNodes = mutableListOf<android.view.accessibility.AccessibilityNodeInfo>()
                            findEditableNodes(rootNode, editableNodes)
                            
                            if (editableNodes.isNotEmpty()) {
                                log("🔍 找到 ${editableNodes.size} 个可编辑节点，尝试第一个")
                                val editNode = editableNodes[0]
                                
                                // 先点击聚焦
                                editNode.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_FOCUS)
                                editNode.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_CLICK)
                                Thread.sleep(300)
                                
                                // 再设置文本
                                val arguments = android.os.Bundle()
                                arguments.putCharSequence(
                                    android.view.accessibility.AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                                    text
                                )
                                val success = editNode.performAction(
                                    android.view.accessibility.AccessibilityNodeInfo.ACTION_SET_TEXT,
                                    arguments
                                )
                                
                                editableNodes.forEach { it.recycle() }
                                
                                if (success) {
                                    log("✅ 文字已设置到可编辑节点")
                                    inputSuccess = true
                                }
                            }
                        }
                        rootNode.recycle()
                    } else {
                        log("⚠️ 无法获取当前窗口")
                    }
                } catch (e: Exception) {
                    log("❌ 设置文本失败: ${e.message}")
                }
            }
            
            // 方法3：剪贴板粘贴
            if (!inputSuccess) {
                log("🔄 尝试剪贴板粘贴...")
                try {
                    // 在主线程设置剪贴板
                    val handler = android.os.Handler(android.os.Looper.getMainLooper())
                    handler.post {
                        try {
                            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            val clip = ClipData.newPlainText("AutoGLM Input", text)
                            clipboard.setPrimaryClip(clip)
                            log("📋 文字已复制到剪贴板")
                        } catch (e: Exception) {
                            log("❌ 复制到剪贴板失败: ${e.message}")
                        }
                    }
                    
                    Thread.sleep(300)
                    
                    val rootNode = rootInActiveWindow
                    if (rootNode != null) {
                        val focusedNode = rootNode.findFocus(android.view.accessibility.AccessibilityNodeInfo.FOCUS_INPUT)
                        if (focusedNode != null) {
                            val success = focusedNode.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_PASTE)
                            focusedNode.recycle()
                            
                            if (success) {
                                log("✅ 粘贴成功")
                                inputSuccess = true
                            }
                        }
                        rootNode.recycle()
                    }
                } catch (e: Exception) {
                    log("❌ 粘贴失败: ${e.message}")
                }
            }
            
            if (!inputSuccess) {
                log("❌ 所有输入方式都失败了")
                log("💡 请确保输入框已聚焦，或手动切换到 ADB Keyboard")
            }
        }.start()
    }
    
    // 递归查找可编辑的节点
    private fun findEditableNodes(node: android.view.accessibility.AccessibilityNodeInfo, result: MutableList<android.view.accessibility.AccessibilityNodeInfo>) {
        if (node.isEditable) {
            result.add(android.view.accessibility.AccessibilityNodeInfo.obtain(node))
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                findEditableNodes(child, result)
                child.recycle()
            }
        }
    }
    
    // 清除输入框文本（使用 ADB Keyboard）
    fun clearText() {
        log("🗑️ [AutoGLM] Clearing text field")
        try {
            val intent = android.content.Intent().apply {
                action = "ADB_CLEAR_TEXT"
            }
            sendBroadcast(intent)
            log("✅ [AutoGLM] Clear text broadcast sent")
            Thread.sleep(200)
        } catch (e: Exception) {
            log("❌ [AutoGLM] Clear text failed: ${e.message}")
        }
    }
    
    // 切换到 ADB Keyboard（支持自动切换和手动选择器）
    fun switchToAdbKeyboard(): String? {
        log("⌨️ 正在切换到 ADB Keyboard...")
        try {
            // 获取当前输入法
            val currentIme = android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.DEFAULT_INPUT_METHOD
            )
            log("📱 当前输入法: $currentIme")
            
            // 如果已经是 ADB Keyboard，直接返回
            if (currentIme != null && currentIme.contains("com.android.adbkeyboard/.AdbIME")) {
                log("✅ 已经是 ADB Keyboard")
                return currentIme
            }
            
            // 方法1：尝试使用 Settings.Secure.putString（需要 WRITE_SECURE_SETTINGS 权限）
            try {
                val success = android.provider.Settings.Secure.putString(
                    contentResolver,
                    android.provider.Settings.Secure.DEFAULT_INPUT_METHOD,
                    "com.android.adbkeyboard/.AdbIME"
                )
                
                if (success) {
                    Thread.sleep(300)
                    
                    // 验证是否真的切换成功
                    val newIme = android.provider.Settings.Secure.getString(
                        contentResolver,
                        android.provider.Settings.Secure.DEFAULT_INPUT_METHOD
                    )
                    
                    if (newIme != null && newIme.contains("com.android.adbkeyboard/.AdbIME")) {
                        log("✅ 切换成功（通过系统设置）")
                        return currentIme
                    }
                }
                log("⚠️ 系统设置方式未生效")
            } catch (e: SecurityException) {
                log("⚠️ 缺少 WRITE_SECURE_SETTINGS 权限")
            } catch (e: Exception) {
                log("⚠️ 系统设置方式失败: ${e.message}")
            }
            
            // 方法2：尝试使用 Runtime.exec（备用）
            try {
                val process = Runtime.getRuntime().exec(
                    arrayOf("settings", "put", "secure", "default_input_method", "com.android.adbkeyboard/.AdbIME")
                )
                process.waitFor()
                
                Thread.sleep(300)
                
                val newIme = android.provider.Settings.Secure.getString(
                    contentResolver,
                    android.provider.Settings.Secure.DEFAULT_INPUT_METHOD
                )
                
                if (newIme != null && newIme.contains("com.android.adbkeyboard/.AdbIME")) {
                    log("✅ 切换成功（通过命令行）")
                    return currentIme
                }
            } catch (e: Exception) {
                log("⚠️ 命令行方式失败: ${e.message}")
            }
            
            // 切换失败
            log("❌ 自动切换失败，需要授权")
            log("💡 授权命令: adb shell pm grant com.example.moe_social android.permission.WRITE_SECURE_SETTINGS")
            return null
            
        } catch (e: Exception) {
            log("❌ 切换输入法失败: ${e.message}")
            return null
        }
    }
    
    // 恢复原输入法
    fun restoreKeyboard(ime: String?) {
        if (ime == null || ime.isEmpty()) {
            log("⌨️ 无需恢复输入法（无保存的原输入法）")
            return
        }
        
        log("⌨️ 正在恢复输入法: $ime")
        
        // 方法1：使用 Settings.Secure.putString（需要 WRITE_SECURE_SETTINGS 权限）
        try {
            val success = android.provider.Settings.Secure.putString(
                contentResolver,
                android.provider.Settings.Secure.DEFAULT_INPUT_METHOD,
                ime
            )
            
            if (success) {
                Thread.sleep(300)
                val newIme = android.provider.Settings.Secure.getString(
                    contentResolver,
                    android.provider.Settings.Secure.DEFAULT_INPUT_METHOD
                )
                if (newIme == ime) {
                    log("✅ 输入法已恢复: $ime")
                    return
                }
            }
        } catch (e: Exception) {
            log("⚠️ Settings.Secure.putString 恢复失败: ${e.message}")
        }
        
        // 方法2：使用 Runtime.exec（备用）
        try {
            val process = Runtime.getRuntime().exec(
                arrayOf("settings", "put", "secure", "default_input_method", ime)
            )
            process.waitFor()
            
            Thread.sleep(300)
            val newIme = android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.DEFAULT_INPUT_METHOD
            )
            if (newIme == ime) {
                log("✅ 输入法已恢复: $ime")
                return
            }
        } catch (e: Exception) {
            log("⚠️ Runtime.exec 恢复失败: ${e.message}")
        }
        
        log("❌ 输入法恢复失败，请手动切换回原输入法")
        log("💡 提示：授权后可自动切换 - adb shell pm grant com.example.moe_social android.permission.WRITE_SECURE_SETTINGS")
    }

    // 显式保存当前输入法为"原输入法"
    fun saveCurrentIme() {
        try {
            val currentIme = android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.DEFAULT_INPUT_METHOD
            )
            // 只有当 sessionOriginalIme 为空时才保存，防止覆盖
            if (sessionOriginalIme == null && currentIme != null) {
                sessionOriginalIme = currentIme
                log("💾 已保存原输入法: $currentIme")
            }
        } catch (e: Exception) {
            log("❌ 保存输入法失败: $e")
        }
    }

    // 开启输入模式（切换到 ADB Keyboard 并保持）
    fun enableInputMode() {
        log("⌨️ 开启输入模式...")
        if (sessionOriginalIme == null) {
            // 只有当之前没有开启会话时，才保存当前的 IME
            sessionOriginalIme = switchToAdbKeyboard()
            if (sessionOriginalIme != null) {
                log("⌨️ 输入模式已开启，原输入法已保存: $sessionOriginalIme")
            } else {
                log("⚠️ 输入模式开启失败（切换 ADB Keyboard 失败）")
            }
        } else {
             // 已经开启了，确保是 ADB Keyboard
             switchToAdbKeyboard()
             log("⌨️ 输入模式已启用，重新强制 ADB Keyboard")
        }
    }

    // 关闭输入模式（恢复原输入法）
    fun disableInputMode() {
        log("⌨️ 关闭输入模式...")
        if (sessionOriginalIme != null) {
            restoreKeyboard(sessionOriginalIme)
            val restoredIme = sessionOriginalIme
            sessionOriginalIme = null
            log("⌨️ 输入模式已关闭，已恢复: $restoredIme")
        } else {
            log("⌨️ 输入模式未启用，无需恢复")
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
            
            log("📱 已扫描到 ${installedApps.size} 个已安装应用")
        } catch (e: Exception) {
            log("❌ 获取应用列表失败: ${e.message}")
        }
        return installedApps
    }

    // 常用应用包名映射（优先级最高）
    private val commonAppPackages = mapOf(
        // 短视频/社交
        "快手" to "com.smile.gifmaker",
        "快手极速版" to "com.kuaishou.nebula",
        "抖音" to "com.ss.android.ugc.aweme",
        "抖音极速版" to "com.ss.android.ugc.aweme.lite",
        "微信" to "com.tencent.mm",
        "QQ" to "com.tencent.mobileqq",
        "微博" to "com.sina.weibo",
        "小红书" to "com.xingin.xhs",
        "哔哩哔哩" to "tv.danmaku.bili",
        "B站" to "tv.danmaku.bili",
        "bilibili" to "tv.danmaku.bili",
        
        // 购物
        "淘宝" to "com.taobao.taobao",
        "京东" to "com.jingdong.app.mall",
        "拼多多" to "com.xunmeng.pinduoduo",
        "闲鱼" to "com.taobao.idlefish",
        "支付宝" to "com.eg.android.AlipayGphone",
        
        // 外卖/生活
        "美团" to "com.sankuai.meituan",
        "饿了么" to "me.ele",
        "大众点评" to "com.dianping.v1",
        
        // 地图
        "高德地图" to "com.autonavi.minimap",
        "百度地图" to "com.baidu.BaiduMap",
        "腾讯地图" to "com.tencent.map",
        
        // 音乐
        "网易云音乐" to "com.netease.cloudmusic",
        "QQ音乐" to "com.tencent.qqmusic",
        "酷狗音乐" to "com.kugou.android",
        "酷我音乐" to "cn.kuwo.player",
        
        // 资讯
        "今日头条" to "com.ss.android.article.news",
        "腾讯新闻" to "com.tencent.news",
        "网易新闻" to "com.netease.newsreader.activity",
        
        // 视频
        "爱奇艺" to "com.qiyi.video",
        "优酷" to "com.youku.phone",
        "腾讯视频" to "com.tencent.qqlive",
        "芒果TV" to "com.hunantv.imgo.activity",
        
        // 工具
        "百度" to "com.baidu.searchbox",
        "UC浏览器" to "com.UCMobile",
        "夸克" to "com.quark.browser",
        
        // 系统应用
        "设置" to "com.android.settings",
        "相机" to "com.android.camera",
        "相册" to "com.android.gallery3d",
        "浏览器" to "com.android.browser",
        "Chrome" to "com.android.chrome",
        "计算器" to "com.android.calculator2",
        "日历" to "com.android.calendar",
        "时钟" to "com.android.deskclock"
    )
    
    // 启动应用（优先使用包名匹配）
    fun launchApp(appName: String): Boolean {
        log("🚀 ========== 启动应用: '$appName' ==========")

        // 0) 如果传入本身就是包名（例如 com.kuaishou.nebula），直接按包名启动（最可靠）
        // 这样后续提示词也可以直接输出 package 而不是易变的应用名。
        val trimmed = appName.trim()
        val looksLikePackage =
            trimmed.contains(".") &&
            !trimmed.contains(" ") &&
            trimmed.length >= 8
        if (looksLikePackage) {
            log("🧩 输入看起来像包名，直接尝试启动: $trimmed")
            return try {
                val intent = packageManager.getLaunchIntentForPackage(trimmed)
                if (intent != null) {
                    intent.addFlags(
                        android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
                            android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP
                    )
                    startActivity(intent)
                    log("✅ ========== 已按包名启动: $trimmed ==========")
                    true
                } else {
                    log("❌ 包名无启动 Activity: $trimmed")
                    false
                }
            } catch (e: Exception) {
                log("❌ 按包名启动失败: ${e.message}")
                false
            }
        }
        
        // 先获取已安装应用列表，并打印相关应用
        val installedApps = getInstalledApps()
        val keyword = appName.replace("极速版", "").replace("Lite", "").replace("lite", "").trim()
        
        log("🔍 搜索关键词: '$keyword'")
        
        // 打印所有相关的已安装应用
        val relatedApps = installedApps.filter { (name, pkg) ->
            name.contains(keyword, ignoreCase = true) || 
            keyword.contains(name, ignoreCase = true) ||
            pkg.contains(keyword, ignoreCase = true) ||
            (keyword.length >= 2 && name.contains(keyword.take(2)))
        }
        
        if (relatedApps.isNotEmpty()) {
            log("📱 已安装的相关应用 (${relatedApps.size}个):")
            relatedApps.forEach { (name, pkg) ->
                log("   - '$name' → $pkg")
            }
        } else {
            log("⚠️ 未找到包含 '$keyword' 的已安装应用")
        }
        
        var packageName: String? = null
        var matchedName: String? = null
        
        // ===== 第一步：从常用应用包名映射查找 =====
        log("🔎 步骤1: 检查常用应用包名映射...")
        
        // 精确匹配
        if (commonAppPackages.containsKey(appName)) {
            val pkg = commonAppPackages[appName]!!
            log("   映射中有 '$appName' → $pkg, 检查是否安装...")
            if (isAppInstalled(pkg)) {
                packageName = pkg
                matchedName = appName
                log("   ✅ 已安装!")
            } else {
                log("   ❌ 未安装")
            }
        }
        
        // 模糊匹配常用应用
        if (packageName == null) {
            for ((name, pkg) in commonAppPackages) {
                if (appName.contains(name) || name.contains(appName)) {
                    log("   尝试 '$name' → $pkg ...")
                    if (isAppInstalled(pkg)) {
                        packageName = pkg
                        matchedName = name
                        log("   ✅ 找到: '$name' → $pkg")
                        break
                    }
                }
            }
        }
        
        // ===== 第二步：从 AppPackages 预定义列表查找 =====
        if (packageName == null) {
            log("🔎 步骤2: 检查 AppPackages 预定义列表...")
            val pkg = AppPackages.getPackageName(appName)
            if (pkg != null) {
                log("   预定义: '$appName' → $pkg, 检查是否安装...")
                if (isAppInstalled(pkg)) {
                    packageName = pkg
                    matchedName = appName
                    log("   ✅ 已安装!")
                } else {
                    log("   ❌ 未安装")
                }
            } else {
                log("   预定义列表中无此应用")
            }
        }
        
        // ===== 第三步：从已安装应用列表中搜索 =====
        if (packageName == null) {
            log("🔎 步骤3: 从已安装应用列表搜索...")
            
            // 精确匹配应用名
            if (installedApps.containsKey(appName)) {
                packageName = installedApps[appName]
                matchedName = appName
                log("   ✅ 精确匹配: '$appName' → $packageName")
            }
            
            // 模糊匹配应用名
            if (packageName == null) {
                for ((name, pkg) in installedApps) {
                    if (name.contains(appName, ignoreCase = true) || 
                        appName.contains(name, ignoreCase = true) ||
                        name.contains(keyword, ignoreCase = true) || 
                        keyword.contains(name, ignoreCase = true)) {
                        packageName = pkg
                        matchedName = name
                        log("   ✅ 模糊匹配: '$name' → $pkg")
                        break
                    }
                }
            }
        }
        
        // ===== 启动应用 =====
        if (packageName == null) {
            log("❌ ========== 未找到应用: '$appName' ==========")
            return false
        }

        log("📦 启动: $matchedName ($packageName)")
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or 
                               android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP)
                startActivity(intent)
                log("✅ ========== 已启动: $matchedName ==========")
                true
            } else {
                log("❌ 无法创建启动 Intent")
                false
            }
        } catch (e: Exception) {
            log("❌ 启动失败: ${e.message}")
            false
        }
    }
    
    // 检查应用是否已安装
    private fun isAppInstalled(packageName: String): Boolean {
        return try {
            packageManager.getLaunchIntentForPackage(packageName) != null
        } catch (e: Exception) {
            false
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
                log("Screenshot failed: $errorCode")
                callback(null)
            }
        })
    }
}

