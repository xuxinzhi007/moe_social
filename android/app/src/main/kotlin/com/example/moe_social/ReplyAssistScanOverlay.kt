package com.example.moe_social

import android.animation.Animator
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Point
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.os.Build
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator

/**
 * 全屏只读扫描层：在真实气泡上画出温纸描边，扫线掠过后再飞进识屏球。
 * 不抢焦点、不接收触摸，也不移动桌宠窗口。
 */
class ReplyAssistScanOverlay(private val context: Context) {

    data class Bubble(
        val bounds: Rect,
        val isTarget: Boolean,
    )

    companion object {
        private const val TAG = "ReplyAssistScan"
        private const val SCAN_MS = 600L
        private const val HOLD_MS = 180L
        private const val FLY_MS = 400L
        private const val TOTAL_MS = SCAN_MS + HOLD_MS + FLY_MS
    }

    private val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var view: ScanView? = null
    private var animator: ValueAnimator? = null
    private var onComplete: (() -> Unit)? = null
    private var playing = false

    fun isPlaying(): Boolean = playing

    /**
     * 开始播放扫描动画。成功加入窗口返回 true；失败时不回调 [onComplete]，由调用方自行进入思考。
     */
    fun play(
        bubbles: List<Bubble>,
        faceCenter: Point,
        onComplete: () -> Unit,
    ): Boolean {
        dismiss()
        if (bubbles.isEmpty()) return false
        this.onComplete = onComplete
        val scanView = ScanView(context, bubbles, faceCenter)
        view = scanView
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
            format = PixelFormat.TRANSLUCENT
            title = "ReplyAssistScan"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        scanView.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        return try {
            wm.addView(scanView, lp)
            playing = true
            startAnimator(scanView)
            true
        } catch (e: Exception) {
            Log.w(TAG, "无法加入扫描层", e)
            this.onComplete = null
            view = null
            playing = false
            false
        }
    }

    fun updateFaceCenter(point: Point) {
        view?.faceCenter = point
    }

    /** 立刻移除扫描层，不触发完成回调（取消、息屏、桌宠收起时用）。 */
    fun dismiss() {
        onComplete = null
        teardown()
    }

    private fun startAnimator(scanView: ScanView) {
        val anim = ValueAnimator.ofFloat(0f, TOTAL_MS.toFloat()).apply {
            duration = TOTAL_MS
            interpolator = LinearInterpolator()
            addUpdateListener { value ->
                if (!playing) return@addUpdateListener
                scanView.setClock(value.animatedValue as Float)
            }
            addListener(object : Animator.AnimatorListener {
                override fun onAnimationStart(animation: Animator) = Unit
                override fun onAnimationRepeat(animation: Animator) = Unit
                override fun onAnimationCancel(animation: Animator) = Unit
                override fun onAnimationEnd(animation: Animator) {
                    if (!playing) return
                    val cb = onComplete
                    onComplete = null
                    teardown()
                    cb?.invoke()
                }
            })
        }
        animator = anim
        anim.start()
    }

    private fun teardown() {
        playing = false
        animator?.cancel()
        animator = null
        val attached = view
        view = null
        if (attached != null) {
            try {
                wm.removeViewImmediate(attached)
            } catch (_: Exception) {
                try {
                    wm.removeView(attached)
                } catch (_: Exception) {
                }
            }
        }
    }

    private class ScanView(
        context: Context,
        private val bubbles: List<Bubble>,
        var faceCenter: Point,
    ) : View(context) {

        private val paper = 0xFFFBF6EE.toInt()
        private val ink = 0xFF5A4A4A.toInt()
        private val strokeColor = 0xFFE8D9C8.toInt()

        private val boxStroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        private val boxFill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }
        private val scanPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }
        private val tmpRect = RectF()
        private val loc = IntArray(2)

        private val scanEase = AccelerateDecelerateInterpolator()
        private val flyEase = DecelerateInterpolator()

        private var clockMs = 0f
        private val scanStart: Float
        private val scanEnd: Float

        init {
            setBackgroundColor(0x00000000)
            val pad = 12f * resources.displayMetrics.density
            var top = bubbles.minOf { it.bounds.top }.toFloat() - pad
            var bottom = bubbles.maxOf { it.bounds.bottom }.toFloat() + pad
            if (bottom <= top) {
                bottom = top + 1f
            }
            scanStart = top
            scanEnd = bottom
        }

        fun setClock(ms: Float) {
            clockMs = ms
            invalidate()
        }

        override fun onDraw(canvas: Canvas) {
            getLocationOnScreen(loc)
            val ox = loc[0].toFloat()
            val oy = loc[1].toFloat()
            val d = resources.displayMetrics.density

            val scanProgress: Float
            val holdProgress: Float
            val flyProgress: Float
            when {
                clockMs <= SCAN_MS -> {
                    scanProgress = scanEase.getInterpolation(
                        (clockMs / SCAN_MS.toFloat()).coerceIn(0f, 1f),
                    )
                    holdProgress = 0f
                    flyProgress = 0f
                }
                clockMs <= SCAN_MS + HOLD_MS -> {
                    scanProgress = 1f
                    holdProgress = ((clockMs - SCAN_MS) / HOLD_MS.toFloat()).coerceIn(0f, 1f)
                    flyProgress = 0f
                }
                else -> {
                    scanProgress = 1f
                    holdProgress = 1f
                    flyProgress = flyEase.getInterpolation(
                        ((clockMs - SCAN_MS - HOLD_MS) / FLY_MS.toFloat()).coerceIn(0f, 1f),
                    )
                }
            }

            val scanY = scanStart + (scanEnd - scanStart) * scanProgress
            val scanLineAlpha = when {
                flyProgress > 0f -> (1f - flyProgress * 3f).coerceAtLeast(0f)
                holdProgress > 0f -> 1f - holdProgress
                else -> 1f
            }
            if (scanLineAlpha > 0.01f) {
                drawScanLine(canvas, scanY - oy, scanLineAlpha, d)
            }

            for (bubble in bubbles) {
                val reveal = if (scanProgress >= 1f) {
                    1f
                } else {
                    revealAlpha(bubble, scanY)
                }
                if (reveal <= 0.01f) continue
                drawBubble(canvas, bubble, reveal, flyProgress, ox, oy, d)
            }
        }

        private fun revealAlpha(bubble: Bubble, scanY: Float): Float {
            val top = bubble.bounds.top.toFloat()
            if (scanY <= top) return 0f
            val height = (bubble.bounds.height().toFloat()).coerceAtLeast(1f)
            return ((scanY - top) / (height * 0.4f)).coerceIn(0f, 1f)
        }

        private fun drawScanLine(canvas: Canvas, y: Float, alpha: Float, d: Float) {
            val glowH = 18f * d
            val coreH = 2.2f * d
            val a = (alpha * 255f).toInt().coerceIn(0, 255)
            val glow = LinearGradient(
                0f,
                y - glowH,
                0f,
                y + glowH,
                intArrayOf(
                    0x00FBF6EE,
                    (0x4DFBF6EE and 0x00FFFFFF) or (a / 2 shl 24),
                    (0x66E8D9C8 and 0x00FFFFFF) or (a * 2 / 3 shl 24),
                    (0x4DFBF6EE and 0x00FFFFFF) or (a / 2 shl 24),
                    0x00FBF6EE,
                ),
                floatArrayOf(0f, 0.35f, 0.5f, 0.65f, 1f),
                Shader.TileMode.CLAMP,
            )
            scanPaint.shader = glow
            canvas.drawRect(0f, y - glowH, width.toFloat(), y + glowH, scanPaint)
            scanPaint.shader = null
            scanPaint.color = (ink and 0x00FFFFFF) or ((a * 0.55f).toInt() shl 24)
            canvas.drawRoundRect(
                0f,
                y - coreH / 2f,
                width.toFloat(),
                y + coreH / 2f,
                coreH,
                coreH,
                scanPaint,
            )
        }

        private fun drawBubble(
            canvas: Canvas,
            bubble: Bubble,
            reveal: Float,
            fly: Float,
            ox: Float,
            oy: Float,
            d: Float,
        ) {
            val src = bubble.bounds
            val srcCx = src.exactCenterX()
            val srcCy = src.exactCenterY()
            val destX = faceCenter.x.toFloat()
            val destY = faceCenter.y.toFloat()
            val cx = srcCx + (destX - srcCx) * fly
            val cy = srcCy + (destY - srcCy) * fly
            val scale = 1f - 0.88f * fly
            val w = src.width() * scale
            val h = src.height() * scale
            tmpRect.set(
                cx - w / 2f - ox,
                cy - h / 2f - oy,
                cx + w / 2f - ox,
                cy + h / 2f - oy,
            )
            val radius = (10f * d * scale).coerceAtLeast(3f * d)
            val fade = (1f - fly).coerceIn(0f, 1f)
            val alpha = (reveal * fade).coerceIn(0f, 1f)
            if (alpha <= 0.01f || w < 1f || h < 1f) return

            val a = (alpha * 255f).toInt().coerceIn(0, 255)
            boxFill.color = if (bubble.isTarget) {
                (paper and 0x00FFFFFF) or ((a * 0.22f).toInt() shl 24)
            } else {
                (paper and 0x00FFFFFF) or ((a * 0.12f).toInt() shl 24)
            }
            canvas.drawRoundRect(tmpRect, radius, radius, boxFill)

            if (bubble.isTarget) {
                boxStroke.color = (strokeColor and 0x00FFFFFF) or ((a * 0.85f).toInt() shl 24)
                boxStroke.strokeWidth = 3.4f * d * scale.coerceAtLeast(0.35f)
                val outset = 1.6f * d * scale
                tmpRect.inset(-outset, -outset)
                canvas.drawRoundRect(tmpRect, radius + outset, radius + outset, boxStroke)
                tmpRect.inset(outset, outset)
                boxStroke.color = (ink and 0x00FFFFFF) or ((a * 0.92f).toInt() shl 24)
                boxStroke.strokeWidth = 2.8f * d * scale.coerceAtLeast(0.35f)
                canvas.drawRoundRect(tmpRect, radius, radius, boxStroke)
            } else {
                boxStroke.color = (strokeColor and 0x00FFFFFF) or ((a * 0.95f).toInt() shl 24)
                boxStroke.strokeWidth = 2.2f * d * scale.coerceAtLeast(0.3f)
                canvas.drawRoundRect(tmpRect, radius, radius, boxStroke)
            }
        }
    }
}
