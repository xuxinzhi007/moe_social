package com.moe.auto

import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

/**
 * 脚本执行时在屏幕上短暂显示点击/滑动轨迹（需悬浮窗权限）。
 */
object ExecutionOverlayManager {
    private var windowManager: WindowManager? = null
    private var controlRoot: LinearLayout? = null
    private var controlParams: WindowManager.LayoutParams? = null
    private var bubbleView: TextView? = null
    private var panelView: LinearLayout? = null
    private var statusTitleView: TextView? = null
    private var statusDetailView: TextView? = null
    private val handler = Handler(Looper.getMainLooper())
    private var displayMetrics: DisplayMetrics? = null
    private var panelExpanded = false
    private var lastStatusText = "待运行"

    @Volatile
    var enabled: Boolean = true
        set(value) {
            field = value
            if (!value) {
                hideControlConsole()
            }
        }

    fun init(context: Context) {
        if (windowManager != null) return
        val app = context.applicationContext
        windowManager = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        displayMetrics = app.resources.displayMetrics
    }

    fun canDraw(context: Context): Boolean = PermissionHelper.canDrawOverlays(context)

    fun showTap(context: Context, xNorm: Float, yNorm: Float) {
        if (!enabled || !canDraw(context)) return
        ensureInit(context)
        val dm = displayMetrics ?: return
        val px = xNorm.coerceIn(0f, 1f) * dm.widthPixels
        val py = yNorm.coerceIn(0f, 1f) * dm.heightPixels
        showMarker(context, px, py, isSwipe = false)
    }

    fun showSwipe(
        context: Context,
        x1: Float,
        y1: Float,
        x2: Float,
        y2: Float,
    ) {
        if (!enabled || !canDraw(context)) return
        ensureInit(context)
        val dm = displayMetrics ?: return
        val sx = x1.coerceIn(0f, 1f) * dm.widthPixels
        val sy = y1.coerceIn(0f, 1f) * dm.heightPixels
        val ex = x2.coerceIn(0f, 1f) * dm.widthPixels
        val ey = y2.coerceIn(0f, 1f) * dm.heightPixels
        val wm = windowManager ?: return
        val view = SwipeOverlayView(context.applicationContext, sx, sy, ex, ey)
        val params = overlayLayoutParams()
        try {
            wm.addView(view, params)
            handler.postDelayed({
                try {
                    wm.removeView(view)
                } catch (_: Exception) {
                }
            }, 700)
        } catch (_: Exception) {
        }
    }

    fun showControlConsole(context: Context) {
        if (!enabled || !canDraw(context)) return
        ensureInit(context)
        handler.post {
            val wm = windowManager ?: return@post
            if (controlRoot != null) return@post

            val density = displayMetrics?.density ?: 1f
            val root = LinearLayout(context.applicationContext).apply {
                orientation = LinearLayout.VERTICAL
            }
            val bubble = createBubbleView(context)
            val panel = createPanelView(context)
            root.addView(bubble)
            root.addView(panel)

            val params = controlLayoutParams().apply {
                x = (12f * density).toInt()
                y = (72f * density).toInt()
            }

            bindDragBehavior(root, bubble)
            bindBubbleClick(bubble)

            try {
                wm.addView(root, params)
                controlRoot = root
                controlParams = params
                bubbleView = bubble
                panelView = panel
                updateControlStatus(lastStatusText)
            } catch (_: Exception) {
            }
        }
    }

    fun updateControlStatus(text: String) {
        lastStatusText = text
        handler.post {
            statusTitleView?.text = "Moe Auto"
            statusDetailView?.text = text
        }
    }

    fun showStatus(context: Context, text: String) {
        showControlConsole(context)
        updateControlStatus(text)
    }

    fun hideControlConsole() {
        handler.post {
            val wm = windowManager ?: return@post
            val view = controlRoot ?: return@post
            try {
                wm.removeView(view)
            } catch (_: Exception) {
            } finally {
                controlRoot = null
                controlParams = null
                bubbleView = null
                panelView = null
                statusTitleView = null
                statusDetailView = null
                panelExpanded = false
            }
        }
    }

    fun hideStatus() = hideControlConsole()

    private fun showMarker(context: Context, px: Float, py: Float, isSwipe: Boolean) {
        val wm = windowManager ?: return
        val size = if (isSwipe) 1 else kotlin.math.max(80f, (displayMetrics?.density ?: 1f) * 48f).toInt()
        val view = TapOverlayView(context.applicationContext)
        val params = overlayLayoutParams().apply {
            width = size
            height = size
            x = (px - size / 2f).toInt()
            y = (py - size / 2f).toInt()
            gravity = Gravity.TOP or Gravity.START
        }
        try {
            wm.addView(view, params)
            handler.postDelayed({
                try {
                    wm.removeView(view)
                } catch (_: Exception) {
                }
            }, 550)
        } catch (_: Exception) {
        }
    }

    private fun ensureInit(context: Context) {
        init(context)
    }

    private fun overlayLayoutParams(): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )
    }

    private fun controlLayoutParams(): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.START }
    }

    private fun createBubbleView(context: Context): TextView {
        val density = displayMetrics?.density ?: 1f
        val bubble = TextView(context.applicationContext).apply {
            text = "Moe"
            setTextColor(Color.WHITE)
            textSize = 12f
            val padH = (10f * density).toInt()
            val padV = (8f * density).toInt()
            setPadding(padH, padV, padH, padV)
            background = GradientDrawable().apply {
                cornerRadius = 18f * density
                setColor(Color.argb(220, 127, 127, 213))
            }
        }
        return bubble
    }

    private fun createPanelView(context: Context): LinearLayout {
        val density = displayMetrics?.density ?: 1f
        val panel = LinearLayout(context.applicationContext).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            background = GradientDrawable().apply {
                cornerRadius = 14f * density
                setColor(Color.argb(215, 20, 20, 20))
            }
            val pad = (10f * density).toInt()
            setPadding(pad, pad, pad, pad)
        }

        val title = TextView(context.applicationContext).apply {
            setTextColor(Color.WHITE)
            textSize = 12f
            text = "Moe Auto"
        }
        val detail = TextView(context.applicationContext).apply {
            setTextColor(Color.argb(230, 220, 220, 220))
            textSize = 11f
            maxLines = 2
            text = lastStatusText
        }
        val actions = LinearLayout(context.applicationContext).apply {
            orientation = LinearLayout.HORIZONTAL
            val top = (8f * density).toInt()
            setPadding(0, top, 0, 0)
        }

        actions.addView(actionButton(context, "停止") {
            AutoBridge.requestStop()
        })
        actions.addView(actionButton(context, "打开") {
            val app = context.applicationContext
            val intent = Intent(app, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            runCatching { app.startActivity(intent) }
        })
        actions.addView(actionButton(context, "收起") {
            setPanelExpanded(false)
        })

        panel.addView(title)
        panel.addView(detail)
        panel.addView(actions)

        statusTitleView = title
        statusDetailView = detail
        return panel
    }

    private fun actionButton(context: Context, text: String, onClick: () -> Unit): TextView {
        val density = displayMetrics?.density ?: 1f
        return TextView(context.applicationContext).apply {
            this.text = text
            setTextColor(Color.WHITE)
            textSize = 11f
            val padH = (8f * density).toInt()
            val padV = (5f * density).toInt()
            setPadding(padH, padV, padH, padV)
            background = GradientDrawable().apply {
                cornerRadius = 10f * density
                setColor(Color.argb(190, 127, 127, 213))
            }
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            lp.marginEnd = (6f * density).toInt()
            layoutParams = lp
            setOnClickListener { onClick() }
        }
    }

    private fun bindBubbleClick(bubble: TextView) {
        bubble.setOnClickListener {
            setPanelExpanded(!panelExpanded)
        }
    }

    private fun bindDragBehavior(root: View, bubble: TextView) {
        bubble.setOnTouchListener(object : View.OnTouchListener {
            var downRawX = 0f
            var downRawY = 0f
            var dragStartX = 0
            var dragStartY = 0
            var moved = false

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                val params = controlParams ?: return false
                val wm = windowManager ?: return false
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        downRawX = event.rawX
                        downRawY = event.rawY
                        dragStartX = params.x
                        dragStartY = params.y
                        moved = false
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = event.rawX - downRawX
                        val dy = event.rawY - downRawY
                        if (abs(dx) > 4f || abs(dy) > 4f) moved = true
                        params.x = (dragStartX + dx).toInt()
                        params.y = (dragStartY + dy).toInt()
                        try {
                            wm.updateViewLayout(root, params)
                        } catch (_: Exception) {
                        }
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (!moved) {
                            v.performClick()
                        }
                        return true
                    }
                }
                return false
            }
        })
    }

    private fun setPanelExpanded(expanded: Boolean) {
        panelExpanded = expanded
        panelView?.visibility = if (expanded) View.VISIBLE else View.GONE
        if (expanded) {
            handler.removeCallbacks(autoCollapseRunnable)
            handler.postDelayed(autoCollapseRunnable, 8000)
        } else {
            handler.removeCallbacks(autoCollapseRunnable)
        }
    }

    private val autoCollapseRunnable = Runnable { setPanelExpanded(false) }

    private class TapOverlayView(context: Context) : View(context) {
        private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(120, 127, 127, 213) }
        private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = 4f
        }

        override fun onDraw(canvas: Canvas) {
            val r = width / 2f
            canvas.drawCircle(r, r, r * 0.7f, fill)
            canvas.drawCircle(r, r, r * 0.85f, ring)
        }
    }

    private class SwipeOverlayView(
        context: Context,
        private val sx: Float,
        private val sy: Float,
        private val ex: Float,
        private val ey: Float,
    ) : View(context) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(200, 127, 127, 213)
            strokeWidth = 8f
            style = Paint.Style.STROKE
        }
        private val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }

        init {
            val dm = context.resources.displayMetrics
            layoutParams = android.view.ViewGroup.LayoutParams(dm.widthPixels, dm.heightPixels)
        }

        override fun onDraw(canvas: Canvas) {
            canvas.drawLine(sx, sy, ex, ey, paint)
            canvas.drawCircle(sx, sy, 14f, dot)
            canvas.drawCircle(ex, ey, 14f, dot)
        }
    }
}
