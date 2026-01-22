package com.example.moe_social

import android.app.Activity
import android.provider.Settings
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager

/**
 * 透明 Activity：专门用于弹出输入法选择器。
 *
 * 为什么需要它：
 * - Flutter 任务正常结束时，AutoGLM 可能已经把用户带到别的 App/桌面；
 * - 这时直接从 Flutter/MainActivity 调用 showInputMethodPicker() 很可能因为不在前台而不弹；
 * - 用一个透明 Activity 拉起到前台后再弹选择器，成功率最高。
 */
class ImePickerActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var startTs: Long = 0L
    private var lastIme: String? = null
    private var mode: String = "to_non_adb"
    private var inferredMode: Boolean = false
    private var targetIme: String? = null

    private fun isAdbIme(id: String?): Boolean {
        if (id.isNullOrBlank()) return false
        return id.contains("adbkeyboard", ignoreCase = true) || id.contains("AdbIME", ignoreCase = true)
    }

    private fun getCurrentImeId(): String? {
        return try {
            Settings.Secure.getString(contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
        } catch (_: Exception) {
            null
        }
    }

    private fun showPicker() {
        try {
            val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showInputMethodPicker()
            Log.i("AutoGLM", "📱 [IME Picker] showInputMethodPicker called")
        } catch (e: Exception) {
            Log.i("AutoGLM", "❌ [IME Picker] showInputMethodPicker failed: ${e.message}")
        }
    }

    private val pollImeRunnable = object : Runnable {
        override fun run() {
            val now = System.currentTimeMillis()
            val current = getCurrentImeId()

            if (current != lastIme) {
                Log.i("AutoGLM", "📱 [IME Picker] Current IME changed: $lastIme -> $current")
                lastIme = current
            }

            // 依据 mode 判断“切换完成”的条件
            val done = when (mode) {
                // 开始任务：等到切到 ADB Keyboard 才算完成
                "to_adb" -> isAdbIme(current)
                // 结束任务：等到离开 ADB Keyboard 才算完成
                // 如果提供了 targetIme，则以“切回 targetIme”为准；否则退化为“只要不是ADB就行”
                "to_non_adb" -> {
                    val t = targetIme
                    if (!t.isNullOrBlank()) current == t else !isAdbIme(current)
                }
                else -> !isAdbIme(current)
            }

            if (done) {
                Log.i("AutoGLM", "✅ [IME Picker] done(mode=$mode), finish")
                finish()
                return
            }
            
            // 超时保护：2分钟自动退出（用户可再次触发）
            if (now - startTs > 120_000) {
                Log.i("AutoGLM", "⏳ [IME Picker] timeout, finish")
                finish()
                return
            }

            handler.postDelayed(this, 500)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startTs = System.currentTimeMillis()
        lastIme = getCurrentImeId()
        
        // mode 可能因为某些 ROM/调用链问题拿不到；拿不到时做“自推断”，避免再出现一闪即消失
        val extraMode = intent?.getStringExtra("mode")
        targetIme = intent?.getStringExtra("targetIme")
        if (extraMode == "to_adb" || extraMode == "to_non_adb") {
            mode = extraMode
            inferredMode = false
        } else {
            // 推断：当前不是ADB → 说明是“开始任务”要切到ADB；当前是ADB → 说明是“结束任务”要切回常用输入法
            mode = if (isAdbIme(lastIme)) "to_non_adb" else "to_adb"
            inferredMode = true
        }

        Log.i(
            "AutoGLM",
            "📱 [IME Picker] onCreate, mode=$mode, inferred=$inferredMode, targetIme=$targetIme, current IME=$lastIme"
        )

        // 确保能在锁屏/后台切到前台（尽量提高弹窗成功率）
        try {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        } catch (_: Exception) {
            // ignore
        }

        // 给用户一个可见的“等待切换”页面（否则 MIUI 可能立刻切回 MainActivity）
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 96, 48, 48)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        val title = TextView(this).apply {
            text = "请输入法切换"
            textSize = 20f
            setTextColor(0xFFFFFFFF.toInt())
        }

        val desc = TextView(this).apply {
            text = when (mode) {
                "to_adb" -> "请选择 ADB Keyboard 作为当前输入法。\n切换成功后，此页面会自动关闭。\n\n如果选择器一闪而过，可点“重新弹出选择器”。"
                "to_non_adb" -> if (!targetIme.isNullOrBlank()) {
                    "请选择切换回原输入法（目标：$targetIme）。\n切换成功后，此页面会自动关闭。\n\n如果选择器一闪而过，可点“重新弹出选择器”。"
                } else {
                    "请选择您常用的输入法（离开 ADB Keyboard）。\n切换成功后，此页面会自动关闭。\n\n如果选择器一闪而过，可点“重新弹出选择器”。"
                }
                else -> "请选择要使用的输入法。\n切换成功后，此页面会自动关闭。\n\n如果选择器一闪而过，可点“重新弹出选择器”。"
            }
            textSize = 14f
            setTextColor(0xCCFFFFFF.toInt())
        }

        val btn = Button(this).apply {
            text = "重新弹出选择器"
            setOnClickListener {
                showPicker()
            }
        }

        root.addView(title)
        root.addView(desc)
        root.addView(btn)
        setContentView(root)
    }

    override fun onDestroy() {
        handler.removeCallbacks(pollImeRunnable)
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        // 每次回到前台都尝试弹一次，并开始轮询直到用户切换完成
        Log.i("AutoGLM", "📱 [IME Picker] onResume, mode=$mode")
        showPicker()
        handler.removeCallbacks(pollImeRunnable)
        handler.postDelayed(pollImeRunnable, 250)
    }
}

