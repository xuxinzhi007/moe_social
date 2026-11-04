package com.example.moe_social

import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.annotation.SuppressLint
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.PixelFormat
import android.graphics.Point
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import kotlin.math.hypot

/**
 * 贴纸桌宠 WindowManager 层：拖/点分离，点开气泡、再点或点空白收回。
 * 不抢焦点，窗外触摸交给微信。
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

    private var breathe: ObjectAnimator? = null

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
        bindFaceTouch(face)
        bindOutsideTouch(view)

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
            x = (screen.x - dp(60)).coerceAtLeast(0)
            y = dp(120)
        }
        params = lp
        wm.addView(view, lp)
        visible = true
        collapse()
    }

    fun hide() {
        requestToken += 1
        breathe?.cancel()
        breathe = null
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
        params = null
        visible = false
        phase = Phase.IDLE
    }

    fun showListening() {
        if (!visible) show()
        rememberFaceAnchor()
        phase = Phase.LISTENING
        face?.expression = ReplyAssistPetExpression.LISTENING
        stopBreathe()
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
        stopBreathe()
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
        stopBreathe()
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
        stopBreathe()
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
        updateStackGravity()
        relayoutKeepingFaceAnchor()
    }

    fun collapse() {
        requestToken += 1
        phase = Phase.IDLE
        face?.expression = ReplyAssistPetExpression.IDLE
        thinkRow?.visibility = View.GONE
        copiedView?.visibility = View.GONE
        optionsStack?.let {
            it.removeAllViews()
            it.visibility = View.GONE
        }
        startBreathe()
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
                        clampToScreen()
                        root?.let { wm.updateViewLayout(it, lp) }
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (dragging) {
                        updateStackGravity()
                        clampToScreen()
                        root?.let { wm.updateViewLayout(it, lp) }
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
        val loc = IntArray(2)
        f.getLocationOnScreen(loc)
        if (loc[0] != 0 || loc[1] != 0 || f.width > 0) {
            faceAnchorX = loc[0]
            faceAnchorY = loc[1]
        }
    }

    private fun relayoutKeepingFaceAnchor() {
        val view = root ?: return
        val lp = params ?: return
        view.post {
            if (root !== view) return@post
            updateStackGravity()
            val f = face ?: return@post
            val loc = IntArray(2)
            f.getLocationOnScreen(loc)
            if (faceAnchorX != 0 || faceAnchorY != 0) {
                lp.x -= loc[0] - faceAnchorX
                lp.y -= loc[1] - faceAnchorY
            }
            clampToScreen()
            try {
                wm.updateViewLayout(view, lp)
            } catch (_: Exception) {
            }
        }
    }

    private fun updateStackGravity() {
        val view = root as? LinearLayout ?: return
        val screen = screenSize()
        val f = face
        val loc = IntArray(2)
        f?.getLocationOnScreen(loc)
        val cx = if (f != null) loc[0] + f.width / 2 else (params?.x ?: 0)
        val onRight = cx > screen.x / 2
        val g = if (onRight) Gravity.END else Gravity.START
        view.gravity = g
        optionsStack?.gravity = g
    }

    private fun clampToScreen() {
        val lp = params ?: return
        val view = root ?: return
        val screen = screenSize()
        val w = if (view.width > 0) view.width else dp(60)
        val h = if (view.height > 0) view.height else dp(60)
        lp.x = lp.x.coerceIn(0, (screen.x - w).coerceAtLeast(0))
        lp.y = lp.y.coerceIn(0, (screen.y - h).coerceAtLeast(0))
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

    private fun startBreathe() {
        val f = face ?: return
        stopBreathe()
        val anim = ObjectAnimator.ofPropertyValuesHolder(
            f,
            PropertyValuesHolder.ofFloat(View.SCALE_X, 1f, 1.06f, 1f),
            PropertyValuesHolder.ofFloat(View.SCALE_Y, 1f, 1.06f, 1f),
        ).apply {
            duration = 2400
            repeatCount = ObjectAnimator.INFINITE
            interpolator = AccelerateDecelerateInterpolator()
        }
        breathe = anim
        anim.start()
    }

    private fun stopBreathe() {
        breathe?.cancel()
        breathe = null
        face?.scaleX = 1f
        face?.scaleY = 1f
    }

    private fun dp(value: Int): Int = (value * density).toInt()
}
