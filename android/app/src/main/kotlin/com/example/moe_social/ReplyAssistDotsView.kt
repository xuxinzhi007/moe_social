package com.example.moe_social

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import android.view.animation.LinearInterpolator
import kotlin.math.sin

/** 听/想态三点循环，不依赖 PNG 帧。 */
class ReplyAssistDotsView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : View(context, attrs, defStyleAttr) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFF5E6AD2.toInt()
    }
    private var t = 0f
    private var paused = false
    private val animator = ValueAnimator.ofFloat(0f, (Math.PI * 2).toFloat()).apply {
        duration = 1100
        repeatCount = ValueAnimator.INFINITE
        interpolator = LinearInterpolator()
        addUpdateListener {
            t = it.animatedValue as Float
            invalidate()
        }
    }

    fun pause() {
        paused = true
        if (animator.isStarted) animator.cancel()
    }

    fun resume() {
        paused = false
        startIfVisible()
    }

    private fun startIfVisible() {
        if (paused) return
        if (isAttachedToWindow && visibility == VISIBLE && !animator.isStarted) {
            animator.start()
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        startIfVisible()
    }

    override fun onDetachedFromWindow() {
        animator.cancel()
        super.onDetachedFromWindow()
    }

    override fun onVisibilityChanged(changedView: View, visibility: Int) {
        super.onVisibilityChanged(changedView, visibility)
        if (visibility == VISIBLE) {
            startIfVisible()
        } else {
            animator.cancel()
        }
    }

    override fun onDraw(canvas: Canvas) {
        val d = resources.displayMetrics.density
        val r = 1.6f * d
        val midY = height / 2f
        val gap = width / 4f
        for (i in 0 until 3) {
            val wave = (sin((t + i * 0.9f).toDouble()).toFloat() + 1f) / 2f
            val y = midY - wave * 2.2f * d
            paint.alpha = (110 + 145 * wave).toInt()
            canvas.drawCircle(gap * (i + 1), y, r, paint)
        }
        paint.alpha = 255
    }
}
