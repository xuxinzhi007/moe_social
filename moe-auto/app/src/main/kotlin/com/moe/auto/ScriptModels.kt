package com.moe.auto

import org.json.JSONArray
import org.json.JSONObject

data class AutoScript(
    val id: String,
    val name: String,
    val version: Int,
    val loop: Int,
    val steps: List<ScriptStep>,
)

sealed class ScriptStep {
    data class Wait(val ms: Long) : ScriptStep()
    data class Tap(val x: Float, val y: Float) : ScriptStep()
    data class Swipe(
        val x1: Float,
        val y1: Float,
        val x2: Float,
        val y2: Float,
        val durationMs: Long,
    ) : ScriptStep()

    data class ClickText(val text: String, val timeoutMs: Long) : ScriptStep()
    data class WaitForText(val text: String, val timeoutMs: Long) : ScriptStep()
    data class OcrClick(val text: String, val timeoutMs: Long) : ScriptStep()
    data class OcrWait(val text: String, val timeoutMs: Long) : ScriptStep()
    data class ClickImage(
        val imagePath: String,
        val threshold: Float,
        val timeoutMs: Long,
        val scaleMin: Float,
        val scaleMax: Float,
    ) : ScriptStep()
    data class Input(val text: String) : ScriptStep()
    data class Launch(val packageName: String) : ScriptStep()
    data object Back : ScriptStep()
    data object Home : ScriptStep()
    data object Recents : ScriptStep()
    data class Log(val message: String) : ScriptStep()
    data class Unknown(val action: String) : ScriptStep()
}

object ScriptParser {
    fun parse(json: String): AutoScript {
        val root = JSONObject(json)
        val stepsJson = root.optJSONArray("steps") ?: JSONArray()
        val steps = buildList {
            for (i in 0 until stepsJson.length()) {
                add(parseStep(stepsJson.getJSONObject(i)))
            }
        }
        return AutoScript(
            id = root.optString("id", "unnamed"),
            name = root.optString("name", "未命名脚本"),
            version = root.optInt("version", 1),
            loop = root.optInt("loop", 1).coerceAtLeast(1),
            steps = steps,
        )
    }

    private fun parseStep(obj: JSONObject): ScriptStep {
        return when (obj.getString("action")) {
            "wait" -> ScriptStep.Wait(obj.optLong("ms", 500))
            "tap" -> ScriptStep.Tap(
                obj.optDouble("x", 0.5).toFloat(),
                obj.optDouble("y", 0.5).toFloat(),
            )
            "swipe" -> ScriptStep.Swipe(
                obj.optDouble("x1", 0.5).toFloat(),
                obj.optDouble("y1", 0.7).toFloat(),
                obj.optDouble("x2", 0.5).toFloat(),
                obj.optDouble("y2", 0.3).toFloat(),
                obj.optLong("duration_ms", 350),
            )
            "click_text" -> ScriptStep.ClickText(
                obj.getString("text"),
                obj.optLong("timeout_ms", 5000),
            )
            "wait_for_text" -> ScriptStep.WaitForText(
                obj.getString("text"),
                obj.optLong("timeout_ms", 8000),
            )
            "ocr_click", "click_text_ocr" -> ScriptStep.OcrClick(
                obj.getString("text"),
                obj.optLong("timeout_ms", 8000),
            )
            "ocr_wait", "wait_for_text_ocr" -> ScriptStep.OcrWait(
                obj.getString("text"),
                obj.optLong("timeout_ms", 10000),
            )
            "click_image" -> ScriptStep.ClickImage(
                obj.getString("image"),
                obj.optDouble("threshold", 0.82).toFloat(),
                obj.optLong("timeout_ms", 10000),
                obj.optDouble("scale_min", 0.85).toFloat(),
                obj.optDouble("scale_max", 1.15).toFloat(),
            )
            "input" -> ScriptStep.Input(obj.getString("text"))
            "launch" -> ScriptStep.Launch(obj.getString("package"))
            "back" -> ScriptStep.Back
            "home" -> ScriptStep.Home
            "recents" -> ScriptStep.Recents
            "log" -> ScriptStep.Log(obj.optString("message", ""))
            else -> ScriptStep.Unknown(obj.optString("action", "?"))
        }
    }
}
