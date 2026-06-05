package com.moe.auto.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.moe.auto.ScriptStep
import com.moe.auto.stepLabel
import org.json.JSONObject

@Composable
fun ScriptFlowchartView(
    steps: List<ScriptStep>,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        if (steps.isEmpty()) {
            Text(
                "流程为空，请添加步骤",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            return
        }
        steps.forEachIndexed { index, step ->
            FlowStepNode(index + 1, stepLabel(step))
            if (index < steps.lastIndex) {
                Box(
                    modifier = Modifier
                        .width(2.dp)
                        .height(20.dp)
                        .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.4f)),
                )
            }
        }
        Box(
            modifier = Modifier
                .width(2.dp)
                .height(12.dp)
                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.4f)),
        )
        Text(
            "结束",
            modifier = Modifier
                .clip(RoundedCornerShape(20.dp))
                .background(MaterialTheme.colorScheme.secondaryContainer)
                .padding(horizontal = 16.dp, vertical = 8.dp),
            fontWeight = FontWeight.Medium,
        )
    }
}

@Composable
private fun FlowStepNode(index: Int, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = label,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(MaterialTheme.colorScheme.primaryContainer)
                .padding(horizontal = 12.dp, vertical = 10.dp),
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium,
        )
        Text(
            "#$index",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

fun stepToJson(step: ScriptStep): JSONObject = when (step) {
    is ScriptStep.Wait -> JSONObject().put("action", "wait").put("ms", step.ms)
    is ScriptStep.Tap -> JSONObject().put("action", "tap").put("x", step.x.toDouble()).put("y", step.y.toDouble())
    is ScriptStep.Swipe -> JSONObject()
        .put("action", "swipe")
        .put("x1", step.x1.toDouble()).put("y1", step.y1.toDouble())
        .put("x2", step.x2.toDouble()).put("y2", step.y2.toDouble())
        .put("duration_ms", step.durationMs)
    is ScriptStep.ClickText -> JSONObject().put("action", "click_text").put("text", step.text).put("timeout_ms", step.timeoutMs)
    is ScriptStep.WaitForText -> JSONObject().put("action", "wait_for_text").put("text", step.text).put("timeout_ms", step.timeoutMs)
    is ScriptStep.OcrClick -> JSONObject().put("action", "ocr_click").put("text", step.text).put("timeout_ms", step.timeoutMs)
    is ScriptStep.OcrWait -> JSONObject().put("action", "ocr_wait").put("text", step.text).put("timeout_ms", step.timeoutMs)
    is ScriptStep.ClickImage -> JSONObject()
        .put("action", "click_image")
        .put("image", step.imagePath)
        .put("threshold", step.threshold.toDouble())
        .put("scale_min", step.scaleMin.toDouble())
        .put("scale_max", step.scaleMax.toDouble())
        .put("timeout_ms", step.timeoutMs)
    is ScriptStep.Input -> JSONObject().put("action", "input").put("text", step.text)
    is ScriptStep.Launch -> JSONObject().put("action", "launch").put("package", step.packageName)
    ScriptStep.Back -> JSONObject().put("action", "back")
    ScriptStep.Home -> JSONObject().put("action", "home")
    ScriptStep.Recents -> JSONObject().put("action", "recents")
    is ScriptStep.Log -> JSONObject().put("action", "log").put("message", step.message)
    is ScriptStep.Unknown -> JSONObject().put("action", step.action)
}
