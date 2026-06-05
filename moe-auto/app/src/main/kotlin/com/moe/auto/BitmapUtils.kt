package com.moe.auto

import android.graphics.Bitmap

object BitmapUtils {
    fun cropNormalized(
        source: Bitmap,
        left: Float,
        top: Float,
        right: Float,
        bottom: Float,
    ): Bitmap {
        val l = left.coerceIn(0f, 1f)
        val t = top.coerceIn(0f, 1f)
        val r = right.coerceIn(l + 0.01f, 1f)
        val b = bottom.coerceIn(t + 0.01f, 1f)
        val x = (l * source.width).toInt().coerceIn(0, source.width - 1)
        val y = (t * source.height).toInt().coerceIn(0, source.height - 1)
        val w = ((r - l) * source.width).toInt().coerceAtLeast(1).coerceAtMost(source.width - x)
        val h = ((b - t) * source.height).toInt().coerceAtLeast(1).coerceAtMost(source.height - y)
        return Bitmap.createBitmap(source, x, y, w, h)
    }
}
