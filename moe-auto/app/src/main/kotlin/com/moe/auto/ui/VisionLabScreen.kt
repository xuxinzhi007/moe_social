package com.moe.auto.ui

import android.graphics.Bitmap
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.CameraAlt
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.FileOpen
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Save
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import com.moe.auto.AutoBridge
import com.moe.auto.BitmapUtils
import com.moe.auto.MoeAutoAccessibilityService
import com.moe.auto.ScriptRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VisionLabScreen(
    repository: ScriptRepository,
    serviceConnected: Boolean,
    onBack: () -> Unit,
    onImportImage: () -> Unit,
    onRefreshTemplates: () -> Unit,
    templates: List<File>,
) {
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    var captureBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var cropRect by remember { mutableStateOf(NormRect.smallCenter()) }
    var templateName by remember { mutableStateOf("my_button") }
    var threshold by remember { mutableFloatStateOf(0.82f) }
    var scaleMin by remember { mutableFloatStateOf(0.85f) }
    var scaleMax by remember { mutableFloatStateOf(1.15f) }
    var selectedTemplate by remember { mutableStateOf<File?>(null) }
    var lastTestScore by remember { mutableStateOf<String?>(null) }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text("识图工具") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "返回")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                "截屏后用手指拖动框选小块，角点可缩放，点保存。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = {
                        scope.launch {
                            val svc = AutoBridge.accessibilityService
                            if (svc == null) {
                                snackbar.showSnackbar("请先开启无障碍服务")
                                return@launch
                            }
                            val bmp = withContext(Dispatchers.Default) { svc.captureScreenBitmap() }
                            if (bmp == null) {
                                snackbar.showSnackbar("截图失败（需 Android 11+）")
                            } else {
                                captureBitmap?.recycle()
                                captureBitmap = bmp
                                cropRect = NormRect.smallCenter()
                                lastTestScore = null
                            }
                        }
                    },
                    enabled = serviceConnected,
                    modifier = Modifier.weight(1f),
                ) {
                    Icon(Icons.Rounded.CameraAlt, contentDescription = null)
                    Text("截屏")
                }
                OutlinedButton(onClick = onImportImage, modifier = Modifier.weight(1f)) {
                    Icon(Icons.Rounded.FileOpen, contentDescription = null)
                    Text("导入图")
                }
            }

            captureBitmap?.let { full ->
                Text("拖动选区", style = MaterialTheme.typography.labelLarge)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(300.dp),
                ) {
                    androidx.compose.foundation.Image(
                        bitmap = full.asImageBitmap(),
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Fit,
                    )
                    TouchRectSelector(
                        modifier = Modifier.fillMaxSize(),
                        imageWidth = full.width,
                        imageHeight = full.height,
                        rect = cropRect,
                        onRectChange = { cropRect = it },
                        mode = TouchSelectMode.CropRect,
                    )
                }

                OutlinedTextField(
                    value = templateName,
                    onValueChange = { templateName = it },
                    label = { Text("模板文件名") },
                    modifier = Modifier.fillMaxWidth(),
                )
                Button(
                    onClick = {
                        scope.launch {
                            try {
                                val cropped = BitmapUtils.cropNormalized(
                                    full, cropRect.left, cropRect.top, cropRect.right, cropRect.bottom,
                                )
                                val file = withContext(Dispatchers.IO) {
                                    repository.saveTemplatePng(templateName, cropped)
                                }
                                cropped.recycle()
                                snackbar.showSnackbar("已保存 templates/${file.name}")
                                onRefreshTemplates()
                                selectedTemplate = file
                            } catch (e: Exception) {
                                snackbar.showSnackbar("保存失败: ${e.message}")
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(Icons.Rounded.Save, contentDescription = null)
                    Text("确定保存")
                }
            }

            Text("匹配参数", style = MaterialTheme.typography.titleSmall)
            ThresholdSlider("阈值", threshold) { threshold = it }
            ThresholdSlider("最小缩放", scaleMin, 0.5f..1.5f) { scaleMin = it.coerceAtMost(scaleMax - 0.05f) }
            ThresholdSlider("最大缩放", scaleMax, 0.5f..1.5f) { scaleMax = it.coerceAtLeast(scaleMin + 0.05f) }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = {
                        val file = selectedTemplate ?: templates.firstOrNull() ?: return@OutlinedButton
                        scope.launch {
                            val svc = AutoBridge.accessibilityService as? MoeAutoAccessibilityService
                            if (svc == null) {
                                snackbar.showSnackbar("无障碍未连接")
                                return@launch
                            }
                            val match = withContext(Dispatchers.Default) {
                                svc.testImageMatch(file, threshold, scaleMin, scaleMax)
                            }
                            lastTestScore = if (match != null) {
                                "匹配 ${(match.score * 100).toInt()}%"
                            } else {
                                "未匹配"
                            }
                            snackbar.showSnackbar(lastTestScore ?: "")
                        }
                    },
                    enabled = serviceConnected && templates.isNotEmpty(),
                    modifier = Modifier.weight(1f),
                ) {
                    Icon(Icons.Rounded.PlayArrow, contentDescription = null)
                    Text("测试")
                }
            }
            lastTestScore?.let { Text(it, style = MaterialTheme.typography.bodySmall) }

            templates.forEach { file ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Row(modifier = Modifier.padding(12.dp)) {
                        Text(file.name, modifier = Modifier.weight(1f))
                        OutlinedButton(onClick = { selectedTemplate = file }) { Text("选用") }
                        IconButton(onClick = {
                            repository.deleteTemplate(file)
                            if (selectedTemplate == file) selectedTemplate = null
                            onRefreshTemplates()
                        }) {
                            Icon(Icons.Rounded.Delete, contentDescription = "删除")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ThresholdSlider(
    label: String,
    value: Float,
    range: ClosedFloatingPointRange<Float> = 0.5f..0.98f,
    onChange: (Float) -> Unit,
) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(label, modifier = Modifier.padding(top = 12.dp))
        Slider(value = value, onValueChange = onChange, valueRange = range, modifier = Modifier.weight(1f))
        Text("${"%.2f".format(value)}", modifier = Modifier.padding(top = 12.dp))
    }
}
