package com.moe.auto

fun stepLabel(step: ScriptStep): String = when (step) {
    is ScriptStep.Wait -> "等待 ${step.ms}ms"
    is ScriptStep.Tap -> "点击 (${fmt(step.x)}, ${fmt(step.y)})"
    is ScriptStep.Swipe -> "滑动"
    is ScriptStep.ClickText -> "节点文字「${step.text}」"
    is ScriptStep.WaitForText -> "等待文字「${step.text}」"
    is ScriptStep.OcrClick -> "OCR 点击「${step.text}」"
    is ScriptStep.OcrWait -> "OCR 等待「${step.text}」"
    is ScriptStep.ClickImage -> "识图 ${step.imagePath}"
    is ScriptStep.Input -> "输入文本"
    is ScriptStep.Launch -> {
        val name = InstalledAppsHelper.labelFor(step.packageName)
        if (name != null) "启动 $name" else "启动 ${step.packageName}"
    }
    ScriptStep.Back -> "返回"
    ScriptStep.Home -> "桌面"
    ScriptStep.Recents -> "最近任务"
    is ScriptStep.Log -> step.message.ifBlank { "日志" }
    is ScriptStep.Unknown -> "未知 ${step.action}"
}

private fun fmt(v: Float) = "%.2f".format(v)
