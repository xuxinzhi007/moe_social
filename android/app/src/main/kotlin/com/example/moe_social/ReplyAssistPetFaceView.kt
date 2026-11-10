package com.example.moe_social

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import kotlin.math.min
import kotlin.random.Random

/** 贴纸桌宠五态表情（Canvas，不绑 moe-avatar）。 */
enum class ReplyAssistPetExpression {
    IDLE,
    LISTENING,
    THINKING,
    READY,
    SUCCESS,
}

class ReplyAssistPetFaceView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : View(context, attrs, defStyleAttr) {

    var expression: ReplyAssistPetExpression = ReplyAssistPetExpression.IDLE
        set(value) {
            if (field == value) return
            field = value
            if (value != ReplyAssistPetExpression.IDLE || animationsPaused) {
                cancelBlink()
            } else if (isAttachedToWindow) {
                scheduleNextBlink()
            }
            invalidate()
        }

    /** 画布内轻跳，不改 View 位置，避免拖动/锚点被 translation 带偏。 */
    var bounceOffset: Float = 0f
        set(value) {
            if (field == value) return
            field = value
            invalidate()
        }

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val eye = Paint(Paint.ANTI_ALIAS_FLAG)
    private val mouthRect = RectF()
    private val tmpRect = RectF()

    private val paper = 0xFFFBF6EE.toInt()
    private val stickerEdge = 0xFFFFFFFF.toInt()
    private val ink = 0xFF5A4A4A.toInt()
    private val strokeColor = 0xFFE8D9C8.toInt()
    private val blush = 0x66F5B8B8
    private val highlight = 0x66FFFFFF
    private val shadow = 0x28000000

    private var blinkClosed = 0f
    private var blinkAnimator: ValueAnimator? = null
    private var animationsPaused = false
    private val blinkHandler = Handler(Looper.getMainLooper())
    private val blinkTick = Runnable { playBlink() }

    fun pauseAnimations() {
        animationsPaused = true
        cancelBlink()
    }

    fun resumeAnimations() {
        animationsPaused = false
        if (isAttachedToWindow && expression == ReplyAssistPetExpression.IDLE) {
            scheduleNextBlink(initial = true)
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (!animationsPaused && expression == ReplyAssistPetExpression.IDLE) {
            scheduleNextBlink(initial = true)
        }
    }

    override fun onDetachedFromWindow() {
        cancelBlink()
        blinkHandler.removeCallbacksAndMessages(null)
        super.onDetachedFromWindow()
    }

    private fun scheduleNextBlink(initial: Boolean = false) {
        blinkHandler.removeCallbacks(blinkTick)
        if (animationsPaused || !isAttachedToWindow || expression != ReplyAssistPetExpression.IDLE) return
        val delay = if (initial) 1400L else 2600L + Random.nextLong(0L, 2000L)
        blinkHandler.postDelayed(blinkTick, delay)
    }

    private fun playBlink() {
        if (animationsPaused || !isAttachedToWindow || expression != ReplyAssistPetExpression.IDLE) return
        blinkAnimator?.cancel()
        val anim = ValueAnimator.ofFloat(0f, 1f, 1f, 0f).apply {
            duration = 140
            interpolator = AccelerateDecelerateInterpolator()
            addUpdateListener {
                blinkClosed = it.animatedValue as Float
                invalidate()
            }
            doOnEndCompat { scheduleNextBlink() }
        }
        blinkAnimator = anim
        anim.start()
    }

    private fun cancelBlink() {
        blinkAnimator?.cancel()
        blinkAnimator = null
        if (blinkClosed != 0f) {
            blinkClosed = 0f
            invalidate()
        }
        blinkHandler.removeCallbacks(blinkTick)
    }

    private fun ValueAnimator.doOnEndCompat(block: () -> Unit) {
        addListener(object : android.animation.Animator.AnimatorListener {
            override fun onAnimationStart(animation: android.animation.Animator) = Unit
            override fun onAnimationCancel(animation: android.animation.Animator) = Unit
            override fun onAnimationRepeat(animation: android.animation.Animator) = Unit
            override fun onAnimationEnd(animation: android.animation.Animator) = block()
        })
    }

    override fun onDraw(canvas: Canvas) {
        val d = resources.displayMetrics.density
        val pad = 3.2f * d
        val cx = width / 2f
        val cy = height / 2f + bounceOffset
        val radius = min(width, height) / 2f - pad

        // 轻阴影，像贴在屏幕上的纸贴纸
        fill.color = shadow
        canvas.drawCircle(cx, cy + 1.8f * d, radius * 0.98f, fill)

        // 模切白边
        fill.color = stickerEdge
        canvas.drawCircle(cx, cy, radius + 1.6f * d, fill)

        fill.color = paper
        canvas.drawCircle(cx, cy, radius, fill)

        fill.color = highlight
        canvas.drawCircle(cx - radius * 0.28f, cy - radius * 0.32f, radius * 0.30f, fill)

        stroke.color = strokeColor
        stroke.strokeWidth = 1.1f * d
        canvas.drawCircle(cx, cy, radius - 0.2f * d, stroke)

        fill.color = blush
        val blushR = radius * 0.18f
        canvas.drawCircle(cx - radius * 0.42f, cy + radius * 0.20f, blushR, fill)
        canvas.drawCircle(cx + radius * 0.42f, cy + radius * 0.20f, blushR, fill)

        eye.color = ink
        stroke.color = ink
        val eyeY = cy - radius * 0.06f
        val eyeDx = radius * 0.24f

        when (expression) {
            ReplyAssistPetExpression.IDLE -> {
                drawIdleEyes(canvas, cx, eyeY, eyeDx, d)
                drawSmile(canvas, cx, cy + radius * 0.24f, radius * 0.22f, d, wide = false)
            }
            ReplyAssistPetExpression.LISTENING -> {
                // 圆眼略看向气泡（上方）
                val look = 1.2f * d
                canvas.drawCircle(cx - eyeDx, eyeY - look, 2.7f * d, eye)
                canvas.drawCircle(cx + eyeDx, eyeY - look, 2.7f * d, eye)
                fill.color = 0xFFFFFFFF.toInt()
                canvas.drawCircle(cx - eyeDx - 0.7f * d, eyeY - look - 0.9f * d, 0.85f * d, fill)
                canvas.drawCircle(cx + eyeDx - 0.7f * d, eyeY - look - 0.9f * d, 0.85f * d, fill)
                fill.color = ink
                canvas.drawCircle(cx, cy + radius * 0.28f, 1.45f * d, fill)
            }
            ReplyAssistPetExpression.THINKING -> {
                stroke.strokeWidth = 2.1f * d
                canvas.drawLine(
                    cx - eyeDx - 4.6f * d, eyeY + 1.3f * d,
                    cx - eyeDx + 4.6f * d, eyeY - 0.7f * d, stroke,
                )
                canvas.drawLine(
                    cx + eyeDx - 4.6f * d, eyeY - 0.7f * d,
                    cx + eyeDx + 4.6f * d, eyeY + 1.3f * d, stroke,
                )
                mouthRect.set(
                    cx - 3.0f * d, cy + radius * 0.20f,
                    cx + 3.0f * d, cy + radius * 0.34f,
                )
                stroke.strokeWidth = 1.6f * d
                canvas.drawOval(mouthRect, stroke)
            }
            ReplyAssistPetExpression.READY -> {
                // 弯眼浅笑
                drawHappyEye(canvas, cx - eyeDx, eyeY, 5.2f * d, d)
                drawHappyEye(canvas, cx + eyeDx, eyeY, 5.2f * d, d)
                drawSmile(canvas, cx, cy + radius * 0.24f, radius * 0.24f, d, wide = false)
            }
            ReplyAssistPetExpression.SUCCESS -> {
                stroke.strokeWidth = 2.1f * d
                drawHappyEye(canvas, cx - eyeDx, eyeY, 5.6f * d, d)
                drawHappyEye(canvas, cx + eyeDx, eyeY, 5.6f * d, d)
                drawSmile(canvas, cx, cy + radius * 0.20f, radius * 0.30f, d, wide = true)
            }
        }
    }

    private fun drawIdleEyes(canvas: Canvas, cx: Float, eyeY: Float, eyeDx: Float, d: Float) {
        val halfW = 4.2f * d
        val openH = 1.7f * d
        val h = openH * (1f - blinkClosed).coerceAtLeast(0.12f)
        stroke.style = Paint.Style.STROKE
        stroke.strokeWidth = 1.9f * d
        if (blinkClosed > 0.85f) {
            canvas.drawLine(cx - eyeDx - halfW, eyeY, cx - eyeDx + halfW, eyeY, stroke)
            canvas.drawLine(cx + eyeDx - halfW, eyeY, cx + eyeDx + halfW, eyeY, stroke)
        } else {
            tmpRect.set(cx - eyeDx - halfW, eyeY - h, cx - eyeDx + halfW, eyeY + h)
            canvas.drawOval(tmpRect, stroke)
            tmpRect.set(cx + eyeDx - halfW, eyeY - h, cx + eyeDx + halfW, eyeY + h)
            canvas.drawOval(tmpRect, stroke)
        }
    }

    private fun drawSmile(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        rx: Float,
        d: Float,
        wide: Boolean,
    ) {
        stroke.style = Paint.Style.STROKE
        stroke.strokeWidth = 2f * d
        val ry = if (wide) rx * 0.72f else rx * 0.55f
        mouthRect.set(cx - rx, cy - ry, cx + rx, cy + ry)
        canvas.drawArc(mouthRect, 20f, 140f, false, stroke)
    }

    private fun drawHappyEye(canvas: Canvas, cx: Float, cy: Float, w: Float, d: Float) {
        stroke.style = Paint.Style.STROKE
        stroke.strokeWidth = 2f * d
        val rect = RectF(cx - w / 2f, cy - w * 0.25f, cx + w / 2f, cy + w * 0.7f)
        canvas.drawArc(rect, 200f, 140f, false, stroke)
    }
}
