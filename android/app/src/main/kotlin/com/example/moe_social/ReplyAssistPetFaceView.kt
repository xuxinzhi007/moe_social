package com.example.moe_social

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import kotlin.math.min

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

    override fun onDraw(canvas: Canvas) {
        val d = resources.displayMetrics.density
        val cx = width / 2f
        val cy = height / 2f
        val radius = min(width, height) / 2f - 3f * d

        fill.color = 0x1A3D2B2F
        canvas.drawCircle(cx, cy + 1.6f * d, radius, fill)

        fill.color = 0xFFFFF8F0.toInt()
        canvas.drawCircle(cx, cy, radius, fill)

        fill.color = 0x66FFFFFF
        canvas.drawCircle(cx - radius * 0.28f, cy - radius * 0.32f, radius * 0.28f, fill)

        stroke.color = 0xFFE8D9C8.toInt()
        stroke.strokeWidth = 1.2f * d
        canvas.drawCircle(cx, cy, radius - stroke.strokeWidth / 2f, stroke)

        fill.color = 0x55F5B8B8
        val blushR = radius * 0.16f
        canvas.drawCircle(cx - radius * 0.40f, cy + radius * 0.16f, blushR, fill)
        canvas.drawCircle(cx + radius * 0.40f, cy + radius * 0.16f, blushR, fill)

        eye.color = 0xFF5A4A4A.toInt()
        stroke.color = 0xFF5A4A4A.toInt()
        val eyeY = cy - radius * 0.08f
        val eyeDx = radius * 0.22f

        when (expression) {
            ReplyAssistPetExpression.IDLE -> {
                stroke.strokeWidth = 2.1f * d
                canvas.drawLine(cx - eyeDx - 4f * d, eyeY, cx - eyeDx + 4f * d, eyeY, stroke)
                canvas.drawLine(cx + eyeDx - 4f * d, eyeY, cx + eyeDx + 4f * d, eyeY, stroke)
                drawSmile(canvas, cx, cy + radius * 0.22f, radius * 0.22f, d, false)
            }
            ReplyAssistPetExpression.LISTENING -> {
                canvas.drawCircle(cx - eyeDx, eyeY - 1f * d, 2.6f * d, eye)
                canvas.drawCircle(cx + eyeDx + 1.2f * d, eyeY - 1.4f * d, 2.6f * d, eye)
                fill.color = 0xFF5A4A4A.toInt()
                canvas.drawCircle(cx, cy + radius * 0.28f, 1.5f * d, fill)
            }
            ReplyAssistPetExpression.THINKING -> {
                stroke.strokeWidth = 2.1f * d
                canvas.drawLine(
                    cx - eyeDx - 4.5f * d, eyeY + 1.2f * d,
                    cx - eyeDx + 4.5f * d, eyeY - 0.6f * d, stroke,
                )
                canvas.drawLine(
                    cx + eyeDx - 4.5f * d, eyeY - 0.6f * d,
                    cx + eyeDx + 4.5f * d, eyeY + 1.2f * d, stroke,
                )
                mouthRect.set(
                    cx - 3.2f * d, cy + radius * 0.20f,
                    cx + 3.2f * d, cy + radius * 0.34f,
                )
                stroke.strokeWidth = 1.6f * d
                canvas.drawOval(mouthRect, stroke)
            }
            ReplyAssistPetExpression.READY -> {
                canvas.drawCircle(cx - eyeDx, eyeY, 2.7f * d, eye)
                canvas.drawCircle(cx + eyeDx, eyeY, 2.7f * d, eye)
                fill.color = 0xFFFFFFFF.toInt()
                canvas.drawCircle(cx - eyeDx - 0.8f * d, eyeY - 0.9f * d, 0.8f * d, fill)
                canvas.drawCircle(cx + eyeDx - 0.8f * d, eyeY - 0.9f * d, 0.8f * d, fill)
                drawSmile(canvas, cx, cy + radius * 0.22f, radius * 0.26f, d, false)
            }
            ReplyAssistPetExpression.SUCCESS -> {
                stroke.strokeWidth = 2.1f * d
                drawHappyEye(canvas, cx - eyeDx, eyeY, 5f * d, d)
                drawHappyEye(canvas, cx + eyeDx, eyeY, 5f * d, d)
                drawSmile(canvas, cx, cy + radius * 0.20f, radius * 0.30f, d, true)
            }
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
        stroke.style = Paint.Style.STROKE
    }

    private fun drawHappyEye(canvas: Canvas, cx: Float, cy: Float, w: Float, d: Float) {
        stroke.strokeWidth = 2f * d
        val rect = RectF(cx - w / 2f, cy - w * 0.25f, cx + w / 2f, cy + w * 0.7f)
        canvas.drawArc(rect, 200f, 140f, false, stroke)
    }
}
