package com.moe.auto

import android.graphics.Bitmap
import android.graphics.Rect
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.math.max

object OcrHelper {
    private val recognizer by lazy {
        TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
    }

    data class TextHit(
        val centerXNorm: Float,
        val centerYNorm: Float,
        val matchedText: String,
    )

    suspend fun findText(bitmap: Bitmap, query: String): TextHit? {
        if (query.isBlank()) return null
        val image = InputImage.fromBitmap(bitmap, 0)
        val result = recognize(image) ?: return null
        val w = max(bitmap.width, 1).toFloat()
        val h = max(bitmap.height, 1).toFloat()
        val q = query.trim()

        for (block in result.textBlocks) {
            for (line in block.lines) {
                val lineText = line.text
                if (lineText.contains(q, ignoreCase = true)) {
                    return line.boundingBox?.toHit(lineText, w, h)
                }
                for (element in line.elements) {
                    val t = element.text
                    if (t.contains(q, ignoreCase = true) || q.contains(t, ignoreCase = true)) {
                        return element.boundingBox?.toHit(t, w, h)
                    }
                }
            }
        }
        return null
    }

    private fun Rect.toHit(text: String, w: Float, h: Float): TextHit {
        return TextHit(
            centerXNorm = (exactCenterX() / w).coerceIn(0f, 1f),
            centerYNorm = (exactCenterY() / h).coerceIn(0f, 1f),
            matchedText = text,
        )
    }

    private suspend fun recognize(image: InputImage) =
        suspendCancellableCoroutine { cont ->
            recognizer.process(image)
                .addOnSuccessListener { cont.resume(it) }
                .addOnFailureListener { cont.resume(null) }
        }
}
