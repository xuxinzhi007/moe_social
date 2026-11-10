package com.example.moe_social

import android.animation.ObjectAnimator
import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.PowerManager
import android.graphics.PixelFormat
import android.graphics.Point
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowInsets
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import kotlin.math.hypot

/**
 * 贴纸桌宠 WindowManager 层：拖/点分离，点开气泡、再点或点空白收回。
 * 不抢焦点，窗外触摸交给下层应用。
 *
 * 展开时先 measure/layout，再按小脸屏幕锚点一次写入窗口位置；
 * 限位只约束小脸，避免整窗被气泡撑大后被系统推到中间。
 */
class ReplyAssistPetOverlay(
    private val context: Context,
    private val onIdleTap: () -> Unit,
) {
    enum class Phase {
        IDLE, LISTENING, THINKING, READY, SUCCESS, FALLBACK
    }

    private val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val slop = ViewConfiguration.get(context).scaledTouchSlop
    private val density = context.resources.displayMetrics.density

    private var root: View? = null
    private var face: ReplyAssistPetFaceView? = null
    private var optionsStack: LinearLayout? = null
    private var thinkRow: View? = null
    private var thinkText: TextView? = null
    private var copiedView: View? = null
    private var params: WindowManager.LayoutParams? = null

    private var visible = false
    private var phase: Phase = Phase.IDLE
    private var requestToken = 0
    private var dragging = false
    private var downRawX = 0f
    private var downRawY = 0f
    private var downParamX = 0
    private var downParamY = 0
    private var faceAnchorX = 0
    private var faceAnchorY = 0
    private var hasFaceAnchor = false
    private var windowOriginX = 0
    private var windowOriginY = 0

    private var idleBounce: ObjectAnimator? = null
    private var thinkDots: ReplyAssistDotsView? = null
    private var screenInteractive = true
    private var screenReceiverRegistered = false

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> pauseAllMotion()
                Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> resumeAllMotion()
            }
        }
    }

    fun isVisible(): Boolean = visible

    fun isBusy(): Boolean = phase == Phase.LISTENING || phase == Phase.THINKING

    fun isThinking(): Boolean = phase == Phase.THINKING

    fun beginRequest(): Int {
        requestToken += 1
        return requestToken
    }

    fun isCurrentRequest(token: Int): Boolean = token == requestToken

    fun toggle(): Boolean {
        return if (visible) {
            hide()
            false
        } else {
            show()
            true
        }
    }

    fun show() {
        if (visible && root != null) return
        val view = LayoutInflater.from(context).inflate(R.layout.reply_assist_pet_overlay, null)
        root = view
        face = view.findViewById(R.id.reply_assist_face)
        optionsStack = view.findViewById(R.id.reply_assist_options)
        thinkRow = view.findViewById(R.id.reply_assist_think_row)
        thinkText = view.findViewById(R.id.reply_assist_think_text)
        copiedView = view.findViewById(R.id.reply_assist_copied)
        thinkDots = view.findViewById(R.id.reply_assist_think_dots)
        bindFaceTouch(face)
        bindOutsideTouch(view)
        registerScreenReceiver()

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val screen = screenSize()
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (screen.x - dp(56)).coerceAtLeast(0)
            y = dp(120)
        }
        params = lp
        wm.addView(view, lp)
        visible = true
        collapse()
    }

    fun hide() {
        requestToken += 1
        stopIdleMotion()
        unregisterScreenReceiver()
        val view = root
        if (view != null) {
            try {
                wm.removeView(view)
            } catch (_: Exception) {
            }
        }
        root = null
        face = null
        optionsStack = null
        thinkRow = null
        thinkText = null
        copiedView = null
        thinkDots = null
        params = null
        visible = false
        phase = Phase.IDLE
    }

    fun showListening() {
        if (!visible) show()
        rememberFaceAnchor()
        phase = Phase.LISTENING
        face?.expression = ReplyAssistPetExpression.LISTENING
        stopIdleMotion()
        copiedView?.visibility = View.GONE
        optionsStack?.visibility = View.GONE
        thinkText?.text = context.getString(R.string.reply_assist_listening)
        thinkRow?.visibility = View.VISIBLE
        relayoutKeepingFaceAnchor()
    }

    fun showThinking() {
        if (!visible) show()
        rememberFaceAnchor()
        phase = Phase.THINKING
        face?.expression = ReplyAssistPetExpression.THINKING
        stopIdleMotion()
        copiedView?.visibility = View.GONE
        optionsStack?.visibility = View.GONE
        thinkText?.text = context.getString(R.string.reply_assist_thinking)
        thinkRow?.visibility = View.VISIBLE
        relayoutKeepingFaceAnchor()
    }

    fun showFallback(message: String) {
        if (!visible) show()
        rememberFaceAnchor()
        phase = Phase.FALLBACK
        face?.expression = ReplyAssistPetExpression.THINKING
        stopIdleMotion()
        optionsStack?.visibility = View.GONE
        copiedView?.visibility = View.GONE
        thinkText?.text = message
        thinkRow?.visibility = View.VISIBLE
        relayoutKeepingFaceAnchor()
    }

    fun showOptions(options: List<Pair<String, String>>) {
        if (!visible) show()
        rememberFaceAnchor()
        phase = Phase.READY
        face?.expression = ReplyAssistPetExpression.READY
        stopIdleMotion()
        thinkRow?.visibility = View.GONE
        copiedView?.visibility = View.GONE
        val stack = optionsStack ?: return
        stack.removeAllViews()
        val inflater = LayoutInflater.from(context)
        options.take(3).forEach { (label, text) ->
            val row = inflater.inflate(R.layout.reply_assist_option_bubble, stack, false)
            val body = text.ifBlank { label }
            row.findViewById<TextView>(R.id.option_text).text = body
            val copy = row.findViewById<View>(R.id.option_copy)
            val copyAction = View.OnClickListener { copyText(body) }
            copy.setOnClickListener(copyAction)
            row.setOnClickListener(copyAction)
            stack.addView(row)
        }
        stack.alpha = 0f
        stack.visibility = View.VISIBLE
        stack.animate().alpha(1f).setDuration(220).start()
        relayoutKeepingFaceAnchor()
    }

    fun collapse() {
        requestToken += 1
        rememberFaceAnchor()
        phase = Phase.IDLE
        face?.expression = ReplyAssistPetExpression.IDLE
        thinkRow?.visibility = View.GONE
        copiedView?.visibility = View.GONE
        optionsStack?.let {
            it.removeAllViews()
            it.visibility = View.GONE
        }
        startIdleMotion()
        relayoutKeepingFaceAnchor()
    }

    private fun copyText(text: String) {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("reply_assist", text))
        rememberFaceAnchor()
        phase = Phase.SUCCESS
        face?.expression = ReplyAssistPetExpression.SUCCESS
        copiedView?.apply {
            alpha = 0f
            visibility = View.VISIBLE
            animate().alpha(1f).setDuration(160).start()
        }
        relayoutKeepingFaceAnchor()
        mainHandler.removeCallbacks(hideCopied)
        mainHandler.postDelayed(hideCopied, 1800)
    }

    private val hideCopied = Runnable {
        if (phase != Phase.SUCCESS) return@Runnable
        rememberFaceAnchor()
        copiedView?.visibility = View.GONE
        phase = Phase.READY
        face?.expression = ReplyAssistPetExpression.READY
        relayoutKeepingFaceAnchor()
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun bindFaceTouch(faceView: ReplyAssistPetFaceView?) {
        val target = faceView ?: return
        target.setOnTouchListener { _, event ->
            val lp = params ?: return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    dragging = false
                    downRawX = event.rawX
                    downRawY = event.rawY
                    downParamX = lp.x
                    downParamY = lp.y
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downRawX
                    val dy = event.rawY - downRawY
                    if (!dragging && hypot(dx.toDouble(), dy.toDouble()) > slop) {
                        dragging = true
                    }
                    if (dragging) {
                        lp.x = downParamX + dx.toInt()
                        lp.y = downParamY + dy.toInt()
                        clampFaceToScreen()
                        root?.let { wm.updateViewLayout(it, lp) }
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (dragging) {
                        rememberFaceAnchor()
                        relayoutKeepingFaceAnchor()
                    } else if (event.actionMasked == MotionEvent.ACTION_UP) {
                        onFaceClick()
                    }
                    dragging = false
                    true
                }
                else -> false
            }
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun bindOutsideTouch(view: View) {
        view.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_OUTSIDE) {
                if (phase == Phase.READY || phase == Phase.SUCCESS ||
                    phase == Phase.FALLBACK || phase == Phase.LISTENING ||
                    phase == Phase.THINKING
                ) {
                    collapse()
                }
                true
            } else {
                false
            }
        }
    }

    private fun onFaceClick() {
        when (phase) {
            Phase.IDLE -> onIdleTap()
            Phase.LISTENING, Phase.THINKING ->
                Toast.makeText(context, "还在看～", Toast.LENGTH_SHORT).show()
            Phase.READY, Phase.SUCCESS, Phase.FALLBACK -> collapse()
        }
    }

    private fun rememberFaceAnchor() {
        val f = face ?: return
        val lp = params ?: return
        val view = root ?: return
        val loc = IntArray(2)
        f.getLocationOnScreen(loc)
        if (loc[0] != 0 || loc[1] != 0 || f.isLaidOut) {
            faceAnchorX = loc[0]
            faceAnchorY = loc[1]
            hasFaceAnchor = true
        }
        val rootLoc = IntArray(2)
        view.getLocationOnScreen(rootLoc)
        if (view.width > 0 || rootLoc[0] != 0 || rootLoc[1] != 0) {
            windowOriginX = rootLoc[0] - lp.x
            windowOriginY = rootLoc[1] - lp.y
        }
    }

    private fun relayoutKeepingFaceAnchor() {
        val view = root ?: return
        val lp = params ?: return
        val f = face ?: return

        updateStackGravity()
        measureOverlay(view)

        // 气泡在顶边放不下时，把窗口整体下移，避免裁切；小脸可以略微下移。
        val bounds = visibleBounds()
        if (lp.y + windowOriginY < bounds.top) {
            lp.y = bounds.top - windowOriginY
        }

        clampFaceToScreen()
        try {
            wm.updateViewLayout(view, lp)
        } catch (_: Exception) {
        }
    }

    private fun measureOverlay(view: View) {
        val lp = params ?: return
        val f = face ?: return
        val widthSpec = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        val heightSpec = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        view.measure(widthSpec, heightSpec)
        val maxW = (visibleBounds().width() * 0.72f).toInt().coerceAtLeast(dp(200))
        var w = view.measuredWidth.coerceAtLeast(1)
        var h = view.measuredHeight.coerceAtLeast(1)
        if (w > maxW) {
            view.measure(
                View.MeasureSpec.makeMeasureSpec(maxW, View.MeasureSpec.EXACTLY),
                heightSpec,
            )
            w = view.measuredWidth.coerceAtMost(maxW).coerceAtLeast(1)
            h = view.measuredHeight.coerceAtLeast(1)
        }
        view.layout(0, 0, w, h)
        lp.width = w
        lp.height = h
        if (hasFaceAnchor) {
            lp.x = faceAnchorX - windowOriginX - f.left
            lp.y = faceAnchorY - windowOriginY - f.top
        }
    }

    private fun updateStackGravity() {
        val view = root as? LinearLayout ?: return
        val screen = visibleBounds()
        val f = face
        val faceW = f?.width ?: dp(44)
        val cx = if (f != null && (faceAnchorX != 0 || f.width > 0)) {
            faceAnchorX + faceW / 2
        } else {
            (params?.x ?: 0) + faceW / 2
        }
        val onRight = cx > (screen.left + screen.right) / 2
        val g = if (onRight) Gravity.END else Gravity.START
        view.gravity = g
        optionsStack?.gravity = g
    }

    private fun clampFaceToScreen() {
        val lp = params ?: return
        val f = face ?: return
        val bounds = visibleBounds()
        val faceW = if (f.width > 0) f.width else dp(44)
        val faceH = if (f.height > 0) f.height else dp(44)
        val faceLeft = f.left
        val faceTop = f.top
        val faceScreenX = lp.x + windowOriginX + faceLeft
        val faceScreenY = lp.y + windowOriginY + faceTop
        val clampedX = faceScreenX.coerceIn(bounds.left, (bounds.right - faceW).coerceAtLeast(bounds.left))
        val clampedY = faceScreenY.coerceIn(bounds.top, (bounds.bottom - faceH).coerceAtLeast(bounds.top))
        lp.x += clampedX - faceScreenX
        lp.y += clampedY - faceScreenY
    }

    private fun visibleBounds(): Rect {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val metrics = wm.currentWindowMetrics
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars(),
            )
            val b = metrics.bounds
            return Rect(
                b.left + insets.left,
                b.top + insets.top,
                b.right - insets.right,
                b.bottom - insets.bottom,
            )
        }
        val rect = Rect()
        root?.getWindowVisibleDisplayFrame(rect)
        if (rect.width() > 0 && rect.height() > 0) return rect
        val p = screenSize()
        return Rect(0, 0, p.x, p.y)
    }

    private fun screenSize(): Point {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = wm.currentWindowMetrics.bounds
            Point(bounds.width(), bounds.height())
        } else {
            val p = Point()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getSize(p)
            p
        }
    }

    private fun pauseAllMotion() {
        screenInteractive = false
        stopIdleMotion()
        face?.pauseAnimations()
        thinkDots?.pause()
    }

    private fun resumeAllMotion() {
        if (screenInteractive) return
        screenInteractive = true
        face?.resumeAnimations()
        thinkDots?.resume()
        if (visible && phase == Phase.IDLE) startIdleMotion()
    }

    private fun registerScreenReceiver() {
        if (screenReceiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        val app = context.applicationContext
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            app.registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            app.registerReceiver(screenReceiver, filter)
        }
        screenReceiverRegistered = true
        val pm = app.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isInteractive) pauseAllMotion()
    }

    private fun unregisterScreenReceiver() {
        if (!screenReceiverRegistered) return
        try {
            context.applicationContext.unregisterReceiver(screenReceiver)
        } catch (_: Exception) {
        }
        screenReceiverRegistered = false
    }

    private fun startIdleMotion() {
        if (!screenInteractive) return
        val f = face ?: return
        stopIdleMotion()
        val dy = -2.4f * density
        val anim = ObjectAnimator.ofFloat(f, "bounceOffset", 0f, dy, 0f).apply {
            duration = 2600
            repeatCount = ObjectAnimator.INFINITE
            interpolator = AccelerateDecelerateInterpolator()
        }
        idleBounce = anim
        anim.start()
    }

    private fun stopIdleMotion() {
        idleBounce?.cancel()
        idleBounce = null
        face?.bounceOffset = 0f
    }

    private fun dp(value: Int): Int = (value * density).toInt()
}
