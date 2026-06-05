package com.moe.auto

import android.graphics.Bitmap
import android.graphics.Color
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

object ImageMatcher {
    data class Match(
        val centerXNorm: Float,
        val centerYNorm: Float,
        val score: Float,
    )

    fun findTemplate(
        screen: Bitmap,
        template: Bitmap,
        threshold: Float,
        scaleMin: Float = 0.85f,
        scaleMax: Float = 1.15f,
        scaleSteps: Int = 5,
    ): Match? {
        val screenSmall = scaleDown(screen, 480)
        var best: Match? = null
        val steps = scaleSteps.coerceIn(1, 9)
        for (i in 0 until steps) {
            val scale = if (steps == 1) {
                1f
            } else {
                scaleMin + (scaleMax - scaleMin) * i / (steps - 1)
            }
            val tw = (template.width * scale).toInt().coerceAtLeast(4)
            val th = (template.height * scale).toInt().coerceAtLeast(4)
            val scaled = Bitmap.createScaledBitmap(template, tw, th, true)
            val hit = findTemplateSingleScale(screenSmall, scaled, threshold)
            scaled.recycle()
            if (hit != null && (best == null || hit.score > best.score)) {
                best = hit
            }
        }
        return best
    }

    private fun findTemplateSingleScale(
        screenSmall: Bitmap,
        template: Bitmap,
        threshold: Float,
    ): Match? {
        val templateSmall = scaleDown(template, 120)
        val sw = screenSmall.width
        val sh = screenSmall.height
        val tw = templateSmall.width
        val th = templateSmall.height
        if (tw < 4 || th < 4 || tw > sw || th > sh) return null

        val screenGray = toGray(screenSmall)
        val templateGray = toGray(templateSmall)
        val tMean = templateGray.average().toFloat()
        val tStd = std(templateGray, tMean).coerceAtLeast(1f)

        var bestScore = 0f
        var bestX = 0
        var bestY = 0
        val step = max(2, min(tw, th) / 8)

        for (y in 0..(sh - th) step step) {
            for (x in 0..(sw - tw) step step) {
                val score = normalizedCrossCorrelation(screenGray, templateGray, sw, tw, th, x, y, tMean, tStd)
                if (score > bestScore) {
                    bestScore = score
                    bestX = x
                    bestY = y
                }
            }
        }

        if (bestScore < threshold) return null
        val cx = (bestX + tw / 2f) / sw
        val cy = (bestY + th / 2f) / sh
        return Match(cx.coerceIn(0f, 1f), cy.coerceIn(0f, 1f), bestScore)
    }

    private fun scaleDown(src: Bitmap, maxSide: Int): Bitmap {
        val maxDim = max(src.width, src.height)
        if (maxDim <= maxSide) return src
        val scale = maxSide.toFloat() / maxDim
        val nw = (src.width * scale).toInt().coerceAtLeast(1)
        val nh = (src.height * scale).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(src, nw, nh, true)
    }

    private fun toGray(bmp: Bitmap): FloatArray {
        val w = bmp.width
        val h = bmp.height
        val pixels = IntArray(w * h)
        bmp.getPixels(pixels, 0, w, 0, 0, w, h)
        return FloatArray(pixels.size) { i ->
            val c = pixels[i]
            val r = Color.red(c)
            val g = Color.green(c)
            val b = Color.blue(c)
            (0.299f * r + 0.587f * g + 0.114f * b)
        }
    }

    private fun std(data: FloatArray, mean: Float): Float {
        var sum = 0f
        for (v in data) {
            val d = v - mean
            sum += d * d
        }
        return sqrt(sum / data.size)
    }

    private fun normalizedCrossCorrelation(
        screen: FloatArray,
        template: FloatArray,
        sw: Int,
        tw: Int,
        th: Int,
        ox: Int,
        oy: Int,
        tMean: Float,
        tStd: Float,
    ): Float {
        var sMean = 0f
        val n = tw * th
        for (ty in 0 until th) {
            for (tx in 0 until tw) {
                sMean += screen[(oy + ty) * sw + (ox + tx)]
            }
        }
        sMean /= n
        var numerator = 0f
        var sVar = 0f
        for (ty in 0 until th) {
            for (tx in 0 until tw) {
                val s = screen[(oy + ty) * sw + (ox + tx)]
                val t = template[ty * tw + tx]
                numerator += (s - sMean) * (t - tMean)
                sVar += (s - sMean) * (s - sMean)
            }
        }
        val denom = sqrt(sVar) * tStd * n
        return if (denom <= 0f) 0f else (numerator / denom).coerceIn(-1f, 1f)
    }
}
