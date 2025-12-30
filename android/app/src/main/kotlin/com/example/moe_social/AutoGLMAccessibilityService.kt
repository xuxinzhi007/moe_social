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
    private var overlayView: TextView? = null

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
        
        // 简单创建一个文本视图作为悬浮窗
        overlayView = TextView(this).apply {
            text = "AutoGLM Ready"
            textSize = 14f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#99000000")) // 半透明黑底
            setPadding(20, 20, 20, 20)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) 
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY 
            else 
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or 
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or 
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        params.y = 100 // 初始位置

        try {
            windowManager?.addView(overlayView, params)
        } catch (e: Exception) {
            println("Error adding overlay view: $e")
        }
    }

    fun updateOverlayLog(log: String) {
        // 在主线程更新UI
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        handler.post {
            if (overlayView == null) showOverlay()
            overlayView?.text = "🤖 $log"
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
        val metrics = resources.displayMetrics
        // 也可以使用 windowManager.defaultDisplay.getRealMetrics(metrics) 获取更准确的物理分辨率
        return metrics
    }

    // 执行点击 (输入为相对坐标 0-1000)
    fun performClick(relX: Float, relY: Float) {
        val metrics = getScreenMetrics()
        val x = (relX / 1000f) * metrics.widthPixels
        val y = (relY / 1000f) * metrics.heightPixels
        
        println("Performing click at: $x, $y (rel: $relX, $relY)")

        val path = Path()
        path.moveTo(x, y)
        val builder = GestureDescription.Builder()
        builder.addStroke(GestureDescription.StrokeDescription(path, 0, 100))
        dispatchGesture(builder.build(), null, null)
    }

    // 执行滑动 (输入为相对坐标 0-1000)
    fun performSwipe(relX1: Float, relY1: Float, relX2: Float, relY2: Float, duration: Long) {
        val metrics = getScreenMetrics()
        val x1 = (relX1 / 1000f) * metrics.widthPixels
        val y1 = (relY1 / 1000f) * metrics.heightPixels
        val x2 = (relX2 / 1000f) * metrics.widthPixels
        val y2 = (relY2 / 1000f) * metrics.heightPixels

        println("Performing swipe from $x1,$y1 to $x2,$y2 duration $duration")

        val path = Path()
        path.moveTo(x1, y1)
        path.lineTo(x2, y2)
        val builder = GestureDescription.Builder()
        builder.addStroke(GestureDescription.StrokeDescription(path, 0, duration))
        dispatchGesture(builder.build(), null, null)
    }

    // 执行返回
    fun performBack() {
        println("Performing Global Back")
        performGlobalAction(GLOBAL_ACTION_BACK)
    }

    // 执行Home
    fun performHome() {
        println("Performing Global Home")
        performGlobalAction(GLOBAL_ACTION_HOME)
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

