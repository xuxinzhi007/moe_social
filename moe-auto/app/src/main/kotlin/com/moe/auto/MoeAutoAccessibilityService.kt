package com.moe.auto

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Path
import android.os.Build
import android.os.Bundle
import android.util.DisplayMetrics
import android.util.Log
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import java.io.File
import kotlin.coroutines.resume

class MoeAutoAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "MoeAutoA11y"
    }

    private lateinit var displayMetrics: DisplayMetrics

    override fun onServiceConnected() {
        super.onServiceConnected()
        displayMetrics = resources.displayMetrics
        minimizeAccessibilityUiFootprint()
        AutoBridge.accessibilityService = this
        AutoBridge.appendLog("无障碍服务已连接")
        Log.i(TAG, "connected")
    }

    /** 尽量不请求无障碍悬浮按钮/探索模式，减少系统小图标干扰（部分机型仍会有系统级指示）。 */
    private fun minimizeAccessibilityUiFootprint() {
        val info = serviceInfo ?: return
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = info.flags and
            (AccessibilityServiceInfo.FLAG_REQUEST_ACCESSIBILITY_BUTTON or
                AccessibilityServiceInfo.FLAG_REQUEST_TOUCH_EXPLORATION_MODE or
                AccessibilityServiceInfo.FLAG_ENABLE_ACCESSIBILITY_VOLUME).inv()
        info.notificationTimeout = 200
        serviceInfo = info
    }

    override fun onDestroy() {
        AutoBridge.accessibilityService = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 被动监听，脚本执行时主动读 rootInActiveWindow
    }

    override fun onInterrupt() {
        AutoBridge.appendLog("无障碍服务中断")
    }

    suspend fun tapNormalized(x: Float, y: Float): Boolean {
        val nx = x.coerceIn(0f, 1f)
        val ny = y.coerceIn(0f, 1f)
        ExecutionOverlayManager.showTap(this, nx, ny)
        val px = nx * displayMetrics.widthPixels
        val py = ny * displayMetrics.heightPixels
        val path = Path().apply { moveTo(px, py) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 50))
            .build()
        return dispatchGestureAwait(gesture)
    }

    suspend fun swipeNormalized(
        x1: Float,
        y1: Float,
        x2: Float,
        y2: Float,
        durationMs: Long,
    ): Boolean {
        val nx1 = x1.coerceIn(0f, 1f)
        val ny1 = y1.coerceIn(0f, 1f)
        val nx2 = x2.coerceIn(0f, 1f)
        val ny2 = y2.coerceIn(0f, 1f)
        ExecutionOverlayManager.showSwipe(this, nx1, ny1, nx2, ny2)
        val sx = nx1 * displayMetrics.widthPixels
        val sy = ny1 * displayMetrics.heightPixels
        val ex = nx2 * displayMetrics.widthPixels
        val ey = ny2 * displayMetrics.heightPixels
        val path = Path().apply {
            moveTo(sx, sy)
            lineTo(ex, ey)
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, durationMs.coerceAtLeast(100)))
            .build()
        return dispatchGestureAwait(gesture)
    }

    private suspend fun dispatchGestureAwait(gesture: GestureDescription): Boolean {
        return suspendCancellableCoroutine { cont ->
            val ok = dispatchGesture(
                gesture,
                object : GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        if (cont.isActive) cont.resume(true)
                    }

                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        if (cont.isActive) cont.resume(false)
                    }
                },
                null,
            )
            if (!ok && cont.isActive) {
                cont.resume(false)
            }
        }
    }

    suspend fun clickText(text: String, timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            val root = rootInActiveWindow
            if (root != null) {
                val node = UiFinder.findByText(root, text)
                if (node != null) {
                    val clicked = clickNode(node)
                    if (node !== root) {
                        node.recycle()
                    }
                    root.recycle()
                    if (clicked) return true
                } else {
                    root.recycle()
                }
            }
            delay(200)
        }
        return false
    }

    suspend fun waitForText(text: String, timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            val root = rootInActiveWindow
            if (root != null) {
                val found = UiFinder.containsText(root, text)
                root.recycle()
                if (found) return true
            }
            delay(250)
        }
        return false
    }

    private suspend fun clickNode(node: AccessibilityNodeInfo): Boolean {
        if (node.isClickable && node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
            return true
        }
        var parent = node.parent
        while (parent != null) {
            if (parent.isClickable && parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                parent.recycle()
                return true
            }
            val next = parent.parent
            parent.recycle()
            parent = next
        }
        val rect = android.graphics.Rect()
        node.getBoundsInScreen(rect)
        val cx = rect.centerX().toFloat() / displayMetrics.widthPixels
        val cy = rect.centerY().toFloat() / displayMetrics.heightPixels
        return tapNormalized(cx, cy)
    }

    fun inputText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val edit = UiFinder.findEditable(root) ?: run {
            root.recycle()
            return pasteViaClipboard(text)
        }
        val args = Bundle().apply {
            putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                text,
            )
        }
        val ok = edit.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        if (edit !== root) edit.recycle()
        root.recycle()
        if (ok) return true
        return pasteViaClipboard(text)
    }

    private fun pasteViaClipboard(text: String): Boolean {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("moe-auto", text))
        val root = rootInActiveWindow ?: return false
        val edit = UiFinder.findEditable(root) ?: run {
            root.recycle()
            return false
        }
        edit.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
        val ok = edit.performAction(AccessibilityNodeInfo.ACTION_PASTE)
        if (edit !== root) edit.recycle()
        root.recycle()
        return ok
    }

    fun launchPackage(packageName: String): Boolean {
        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        return true
    }

    fun performGlobalBack(): Boolean = performGlobalAction(GLOBAL_ACTION_BACK)
    fun performGlobalHome(): Boolean = performGlobalAction(GLOBAL_ACTION_HOME)
    fun performGlobalRecents(): Boolean = performGlobalAction(GLOBAL_ACTION_RECENTS)

    suspend fun captureScreenBitmap(): Bitmap? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            AutoBridge.appendLog("截图需要 Android 11+")
            return null
        }
        return takeScreenshotApi30()
    }

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.R)
    private suspend fun takeScreenshotApi30(): Bitmap? = suspendCancellableCoroutine { cont ->
        takeScreenshot(
            Display.DEFAULT_DISPLAY,
            mainExecutor,
            object : TakeScreenshotCallback {
                override fun onSuccess(result: ScreenshotResult) {
                    try {
                        val hw = result.hardwareBuffer
                        val bmp = Bitmap.wrapHardwareBuffer(hw, result.colorSpace)
                        val copy = bmp?.copy(Bitmap.Config.ARGB_8888, false)
                        hw.close()
                        cont.resume(copy)
                    } catch (e: Exception) {
                        cont.resume(null)
                    }
                }

                override fun onFailure(errorCode: Int) {
                    cont.resume(null)
                }
            },
        )
    }

    suspend fun ocrClick(text: String, timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            val bmp = captureScreenBitmap() ?: return false
            val hit = OcrHelper.findText(bmp, text)
            bmp.recycle()
            if (hit != null) {
                AutoBridge.appendLog("OCR 命中「${hit.matchedText}」")
                return tapNormalized(hit.centerXNorm, hit.centerYNorm)
            }
            delay(400)
        }
        return false
    }

    suspend fun ocrWait(text: String, timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            val bmp = captureScreenBitmap() ?: return false
            val hit = OcrHelper.findText(bmp, text)
            bmp.recycle()
            if (hit != null) return true
            delay(450)
        }
        return false
    }

    suspend fun clickImage(
        imageFile: File,
        threshold: Float,
        timeoutMs: Long,
        scaleMin: Float = 0.85f,
        scaleMax: Float = 1.15f,
    ): Boolean {
        val template = android.graphics.BitmapFactory.decodeFile(imageFile.absolutePath)
            ?: return false
        val deadline = System.currentTimeMillis() + timeoutMs
        try {
            while (System.currentTimeMillis() < deadline) {
                val screen = captureScreenBitmap() ?: return false
                val match = ImageMatcher.findTemplate(
                    screen,
                    template,
                    threshold,
                    scaleMin = scaleMin,
                    scaleMax = scaleMax,
                )
                screen.recycle()
                if (match != null) {
                    AutoBridge.appendLog("识图匹配 ${(match.score * 100).toInt()}%")
                    return tapNormalized(match.centerXNorm, match.centerYNorm)
                }
                delay(500)
            }
        } finally {
            template.recycle()
        }
        return false
    }

    suspend fun testImageMatch(
        imageFile: File,
        threshold: Float,
        scaleMin: Float,
        scaleMax: Float,
    ): ImageMatcher.Match? {
        val template = android.graphics.BitmapFactory.decodeFile(imageFile.absolutePath) ?: return null
        val screen = captureScreenBitmap() ?: return null
        return try {
            ImageMatcher.findTemplate(screen, template, threshold, scaleMin, scaleMax)
        } finally {
            screen.recycle()
            template.recycle()
        }
    }
}
