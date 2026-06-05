package com.moe.auto

import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlin.coroutines.coroutineContext

class ScriptExecutor(
    private val service: MoeAutoAccessibilityService,
    private val scriptRepo: ScriptRepository = ScriptRepository(AutoBridge.context()),
) {
    @Volatile
    var stopRequested: Boolean = false
        internal set

    suspend fun run(script: AutoScript): Result<Unit> {
        stopRequested = false
        AutoBridge.appendLog("开始脚本: ${script.name} (循环 ${script.loop})")

        val stepTotal = script.steps.size

        repeat(script.loop) { loopIndex ->
            if (stopRequested || !coroutineContext.isActive) {
                return Result.failure(IllegalStateException("已停止"))
            }
            if (script.loop > 1) {
                AutoBridge.appendLog("—— 第 ${loopIndex + 1}/${script.loop} 轮 ——")
            }
            for ((index, step) in script.steps.withIndex()) {
                if (stopRequested || !coroutineContext.isActive) {
                    return Result.failure(IllegalStateException("已停止"))
                }
                AutoBridge.setRunProgress(
                    RunProgress(
                        scriptName = script.name,
                        stepIndex = index + 1,
                        stepTotal = stepTotal,
                        stepLabel = stepLabel(step),
                        loopIndex = loopIndex + 1,
                        loopTotal = script.loop,
                    ),
                )
                val ok = executeStep(step, index + 1)
                if (!ok) {
                    AutoBridge.appendLog("步骤 ${index + 1} 失败，脚本中止")
                    return Result.failure(IllegalStateException("步骤失败: $step"))
                }
            }
        }

        AutoBridge.appendLog("脚本完成: ${script.name}")
        return Result.success(Unit)
    }

    private suspend fun executeStep(step: ScriptStep, stepNo: Int): Boolean {
        return when (step) {
            is ScriptStep.Wait -> {
                AutoBridge.appendLog("[$stepNo] 等待 ${step.ms}ms")
                delay(step.ms)
                true
            }
            is ScriptStep.Tap -> {
                AutoBridge.appendLog("[$stepNo] 点击 (${step.x}, ${step.y})")
                service.tapNormalized(step.x, step.y)
            }
            is ScriptStep.Swipe -> {
                AutoBridge.appendLog("[$stepNo] 滑动")
                service.swipeNormalized(
                    step.x1,
                    step.y1,
                    step.x2,
                    step.y2,
                    step.durationMs,
                )
            }
            is ScriptStep.ClickText -> {
                AutoBridge.appendLog("[$stepNo] 点击文字「${step.text}」")
                service.clickText(step.text, step.timeoutMs)
            }
            is ScriptStep.WaitForText -> {
                AutoBridge.appendLog("[$stepNo] 等待文字「${step.text}」")
                service.waitForText(step.text, step.timeoutMs)
            }
            is ScriptStep.OcrClick -> {
                AutoBridge.appendLog("[$stepNo] OCR 点击「${step.text}」")
                service.ocrClick(step.text, step.timeoutMs)
            }
            is ScriptStep.OcrWait -> {
                AutoBridge.appendLog("[$stepNo] OCR 等待「${step.text}」")
                service.ocrWait(step.text, step.timeoutMs)
            }
            is ScriptStep.ClickImage -> {
                AutoBridge.appendLog("[$stepNo] 识图点击 ${step.imagePath}")
                val file = scriptRepo.resolveImagePath(step.imagePath)
                if (file == null) {
                    AutoBridge.appendLog("找不到图片: ${step.imagePath}")
                    false
                } else {
                    service.clickImage(
                        file,
                        step.threshold,
                        step.timeoutMs,
                        step.scaleMin,
                        step.scaleMax,
                    )
                }
            }
            is ScriptStep.Input -> {
                AutoBridge.appendLog("[$stepNo] 输入文本")
                service.inputText(step.text)
            }
            is ScriptStep.Launch -> {
                AutoBridge.appendLog("[$stepNo] 启动 ${step.packageName}")
                service.launchPackage(step.packageName)
            }
            ScriptStep.Back -> {
                AutoBridge.appendLog("[$stepNo] 返回")
                service.performGlobalBack()
            }
            ScriptStep.Home -> {
                AutoBridge.appendLog("[$stepNo] Home")
                service.performGlobalHome()
            }
            ScriptStep.Recents -> {
                AutoBridge.appendLog("[$stepNo] 最近任务")
                service.performGlobalRecents()
            }
            is ScriptStep.Log -> {
                AutoBridge.appendLog("[$stepNo] ${step.message}")
                true
            }
            is ScriptStep.Unknown -> {
                AutoBridge.appendLog("[$stepNo] 未知动作: ${step.action}")
                false
            }
        }
    }
}
