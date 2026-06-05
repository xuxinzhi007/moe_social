package com.moe.auto.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.unit.IntSize
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

data class NormRect(
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
) {
    fun clamp(): NormRect {
        val l = left.coerceIn(0f, 1f)
        val t = top.coerceIn(0f, 1f)
        val r = right.coerceIn(l + 0.02f, 1f)
        val b = bottom.coerceIn(t + 0.02f, 1f)
        return NormRect(l, t, r, b)
    }

    companion object {
        fun smallCenter(): NormRect = NormRect(0.4f, 0.45f, 0.6f, 0.55f)
    }
}

enum class TouchSelectMode {
    CropRect,
    TapPoint,
}

data class ImageDisplayMetrics(
    val containerW: Float,
    val containerH: Float,
    val imageW: Int,
    val imageH: Int,
) {
    fun imageBounds(): Rect {
        if (imageW <= 0 || imageH <= 0) return Rect.Zero
        val scale = min(containerW / imageW, containerH / imageH)
        val dw = imageW * scale
        val dh = imageH * scale
        val ox = (containerW - dw) / 2f
        val oy = (containerH - dh) / 2f
        return Rect(ox, oy, ox + dw, oy + dh)
    }

    fun normToLocal(nx: Float, ny: Float): Offset {
        val b = imageBounds()
        return Offset(b.left + nx * b.width, b.top + ny * b.height)
    }

    fun localToNorm(px: Float, py: Float): Offset? {
        val b = imageBounds()
        if (!b.contains(Offset(px, py))) return null
        val nx = ((px - b.left) / b.width).coerceIn(0f, 1f)
        val ny = ((py - b.top) / b.height).coerceIn(0f, 1f)
        return Offset(nx, ny)
    }

    fun normRectToLocal(rect: NormRect): Rect {
        val b = imageBounds()
        return Rect(
            b.left + rect.left * b.width,
            b.top + rect.top * b.height,
            b.left + rect.right * b.width,
            b.top + rect.bottom * b.height,
        )
    }
}

private enum class DragHandle { Move, TopLeft, TopRight, BottomLeft, BottomRight, None }

@Composable
fun TouchRectSelector(
    modifier: Modifier = Modifier,
    imageWidth: Int,
    imageHeight: Int,
    rect: NormRect,
    onRectChange: (NormRect) -> Unit,
    mode: TouchSelectMode = TouchSelectMode.CropRect,
    tapPoint: Offset? = null,
    onTapPoint: ((Float, Float) -> Unit)? = null,
) {
    var containerSize by remember { mutableStateOf(IntSize.Zero) }
    var activeHandle by remember { mutableStateOf(DragHandle.None) }
    var dragStartRect by remember { mutableStateOf(rect) }
    var dragStart by remember { mutableStateOf(Offset.Zero) }

    val metrics = remember(containerSize, imageWidth, imageHeight) {
        ImageDisplayMetrics(
            containerSize.width.toFloat(),
            containerSize.height.toFloat(),
            imageWidth,
            imageHeight,
        )
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .onSizeChanged { containerSize = it }
            .pointerInput(mode, rect, metrics) {
                if (mode == TouchSelectMode.TapPoint) {
                    detectTapGestures { offset ->
                        metrics.localToNorm(offset.x, offset.y)?.let { n ->
                            onTapPoint?.invoke(n.x, n.y)
                        }
                    }
                } else {
                    detectDragGestures(
                        onDragStart = { offset ->
                            dragStart = offset
                            dragStartRect = rect
                            activeHandle = hitHandle(metrics, rect, offset)
                        },
                        onDrag = { change, _ ->
                            val normDelta = metrics.localToNorm(change.position.x, change.position.y)
                                ?: return@detectDragGestures
                            val startNorm = metrics.localToNorm(dragStart.x, dragStart.y) ?: return@detectDragGestures
                            val dx = normDelta.x - startNorm.x
                            val dy = normDelta.y - startNorm.y
                            val updated = when (activeHandle) {
                                DragHandle.Move -> NormRect(
                                    dragStartRect.left + dx,
                                    dragStartRect.top + dy,
                                    dragStartRect.right + dx,
                                    dragStartRect.bottom + dy,
                                ).clamp().let { r ->
                                    val w = r.right - r.left
                                    val h = r.bottom - r.top
                                    NormRect(
                                        (r.left).coerceIn(0f, 1f - w),
                                        (r.top).coerceIn(0f, 1f - h),
                                        (r.left + w).coerceIn(w, 1f),
                                        (r.top + h).coerceIn(h, 1f),
                                    )
                                }
                                DragHandle.TopLeft -> NormRect(
                                    dragStartRect.left + dx,
                                    dragStartRect.top + dy,
                                    dragStartRect.right,
                                    dragStartRect.bottom,
                                ).clamp()
                                DragHandle.TopRight -> NormRect(
                                    dragStartRect.left,
                                    dragStartRect.top + dy,
                                    dragStartRect.right + dx,
                                    dragStartRect.bottom,
                                ).clamp()
                                DragHandle.BottomLeft -> NormRect(
                                    dragStartRect.left + dx,
                                    dragStartRect.top,
                                    dragStartRect.right,
                                    dragStartRect.bottom + dy,
                                ).clamp()
                                DragHandle.BottomRight -> NormRect(
                                    dragStartRect.left,
                                    dragStartRect.top,
                                    dragStartRect.right + dx,
                                    dragStartRect.bottom + dy,
                                ).clamp()
                                DragHandle.None -> rect
                            }
                            onRectChange(updated)
                        },
                        onDragEnd = { activeHandle = DragHandle.None },
                        onDragCancel = { activeHandle = DragHandle.None },
                    )
                }
            },
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val img = metrics.imageBounds()
            if (mode == TouchSelectMode.CropRect) {
                val sel = metrics.normRectToLocal(rect)
                drawRect(Color.Black.copy(alpha = 0.45f), topLeft = Offset.Zero, size = Size(size.width, sel.top))
                drawRect(
                    Color.Black.copy(alpha = 0.45f),
                    topLeft = Offset(0f, sel.bottom),
                    size = Size(size.width, size.height - sel.bottom),
                )
                drawRect(
                    Color.Black.copy(alpha = 0.45f),
                    topLeft = Offset(0f, sel.top),
                    size = Size(sel.left, sel.height),
                )
                drawRect(
                    Color.Black.copy(alpha = 0.45f),
                    topLeft = Offset(sel.right, sel.top),
                    size = Size(size.width - sel.right, sel.height),
                )
                drawRect(Color(0xFF7F7FD5), topLeft = sel.topLeft, size = sel.size, style = Stroke(3f))
                val handle = 18f
                listOf(
                    Offset(sel.left, sel.top),
                    Offset(sel.right, sel.top),
                    Offset(sel.left, sel.bottom),
                    Offset(sel.right, sel.bottom),
                ).forEach { c ->
                    drawCircle(Color.White, handle, c)
                    drawCircle(Color(0xFF7F7FD5), handle - 4f, c)
                }
            } else if (tapPoint != null) {
                val p = metrics.normToLocal(tapPoint.x, tapPoint.y)
                drawCircle(Color(0xFFFF6B6B), 16f, p)
                drawCircle(Color.White, 22f, p, style = Stroke(3f))
            }
            drawRect(Color.White.copy(alpha = 0.08f), topLeft = img.topLeft, size = img.size, style = Stroke(1f))
        }
    }
}

private fun hitHandle(metrics: ImageDisplayMetrics, rect: NormRect, offset: Offset): DragHandle {
    val sel = metrics.normRectToLocal(rect)
    val corners = listOf(
        DragHandle.TopLeft to Offset(sel.left, sel.top),
        DragHandle.TopRight to Offset(sel.right, sel.top),
        DragHandle.BottomLeft to Offset(sel.left, sel.bottom),
        DragHandle.BottomRight to Offset(sel.right, sel.bottom),
    )
    for ((h, c) in corners) {
        if (abs(offset.x - c.x) < 40f && abs(offset.y - c.y) < 40f) return h
    }
    return if (sel.contains(offset)) DragHandle.Move else DragHandle.None
}
