package com.moe.auto.ui

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.CropFree
import androidx.compose.material.icons.rounded.Launch
import androidx.compose.material.icons.rounded.Save
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import com.moe.auto.AutoBridge
import com.moe.auto.BitmapUtils
import android.content.Context
import com.moe.auto.RegionPickerOverlay
import com.moe.auto.ScriptJsonBuilder
import com.moe.auto.ScriptRepository
import com.moe.auto.ScriptStep
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScriptWizardScreen(
    context: Context,
    repository: ScriptRepository,
    serviceConnected: Boolean,
    overlayGranted: Boolean,
    onBack: () -> Unit,
    onSaved: () -> Unit,
) {
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val steps = remember { mutableStateListOf<ScriptStep>() }

    var scriptName by remember { mutableStateOf("wizard_script") }
    var captureBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var pickMode by remember { mutableStateOf<WizardPickMode?>(null) }
    var cropRect by remember { mutableStateOf(NormRect.smallCenter()) }
    var tapPoint by remember { mutableStateOf<Offset?>(null) }
    var showWaitDialog by remember { mutableStateOf(false) }
    var showAppPicker by remember { mutableStateOf(false) }
    var waitMs by remember { mutableStateOf("1000") }

    fun captureFull(forMode: WizardPickMode) {
        scope.launch {
            val svc = AutoBridge.accessibilityService
            if (svc == null) {
                snackbar.showSnackbar("请先开启无障碍")
                return@launch
            }
            val bmp = withContext(Dispatchers.Default) { svc.captureScreenBitmap() }
            if (bmp == null) {
                snackbar.showSnackbar("截图失败")
                return@launch
            }
            captureBitmap?.recycle()
            captureBitmap = bmp
            cropRect = NormRect.smallCenter()
            tapPoint = null
            pickMode = forMode
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text("向导创建") },
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
                "支持跨应用：先「启动应用」再点选/识图。步骤可上移、下移、删除。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (!overlayGranted) {
                Text(
                    "开启悬浮窗后，运行脚本时会显示点击位置",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }

            OutlinedTextField(
                value = scriptName,
                onValueChange = { scriptName = it },
                label = { Text("脚本名称") },
                modifier = Modifier.fillMaxWidth(),
            )

            Text("已录步骤（可调整顺序）", style = MaterialTheme.typography.titleSmall)
            StepListEditor(
                steps = steps,
                onMoveUp = { i -> swapSteps(steps, i, i - 1) },
                onMoveDown = { i -> swapSteps(steps, i, i + 1) },
                onDelete = { i -> steps.removeAt(i) },
            )

            Text("流程图预览", style = MaterialTheme.typography.titleSmall)
            ScriptFlowchartView(steps = steps, modifier = Modifier.fillMaxWidth())

            Text("添加步骤", style = MaterialTheme.typography.titleSmall)
            OutlinedButton(
                onClick = { showAppPicker = true },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(Icons.Rounded.Launch, contentDescription = null)
                Text("启动应用（跨应用第一步）")
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = { captureFull(WizardPickMode.TapPoint) },
                    enabled = serviceConnected,
                    modifier = Modifier.weight(1f),
                ) {
                    Icon(Icons.Rounded.TouchApp, contentDescription = null)
                    Text("点选")
                }
                OutlinedButton(
                    onClick = {
                        if (!overlayGranted) {
                            scope.launch { snackbar.showSnackbar("请先开启悬浮窗权限") }
                            return@OutlinedButton
                        }
                        RegionPickerOverlay.show(
                            context = context,
                            onConfirm = { rect ->
                                scope.launch {
                                    val svc = AutoBridge.accessibilityService ?: return@launch
                                    val full = withContext(Dispatchers.Default) { svc.captureScreenBitmap() }
                                        ?: return@launch
                                    val cropped = BitmapUtils.cropNormalized(
                                        full, rect.left, rect.top, rect.right, rect.bottom,
                                    )
                                    full.recycle()
                                    captureBitmap = cropped
                                    cropRect = NormRect(0f, 0f, 1f, 1f)
                                    pickMode = WizardPickMode.ConfirmImageTemplate
                                }
                            },
                            onCancel = {},
                        )
                    },
                    enabled = serviceConnected && overlayGranted,
                    modifier = Modifier.weight(1f),
                ) {
                    Icon(Icons.Rounded.CropFree, contentDescription = null)
                    Text("框选识图")
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = { captureFull(WizardPickMode.CropImage) },
                    enabled = serviceConnected,
                    modifier = Modifier.weight(1f),
                ) {
                    Text("截图裁切识图")
                }
                OutlinedButton(
                    onClick = { showWaitDialog = true },
                    modifier = Modifier.weight(1f),
                ) {
                    Icon(Icons.Rounded.Add, contentDescription = null)
                    Text("等待")
                }
            }

            pickMode?.let { mode ->
                PickOverlay(
                    bitmap = captureBitmap,
                    mode = mode,
                    cropRect = cropRect,
                    tapPoint = tapPoint,
                    onCropChange = { cropRect = it },
                    onTap = { x, y -> tapPoint = Offset(x, y) },
                    onConfirm = {
                        when (mode) {
                            WizardPickMode.TapPoint -> {
                                val p = tapPoint
                                if (p == null) {
                                    scope.launch { snackbar.showSnackbar("请在图上点一下") }
                                } else {
                                    steps.add(ScriptStep.Tap(p.x, p.y))
                                    pickMode = null
                                    captureBitmap?.recycle()
                                    captureBitmap = null
                                }
                            }
                            WizardPickMode.CropImage, WizardPickMode.ConfirmImageTemplate -> {
                                scope.launch {
                                    val bmp = captureBitmap ?: return@launch
                                    val cropped = if (mode == WizardPickMode.ConfirmImageTemplate) {
                                        bmp
                                    } else {
                                        BitmapUtils.cropNormalized(
                                            bmp,
                                            cropRect.left,
                                            cropRect.top,
                                            cropRect.right,
                                            cropRect.bottom,
                                        )
                                    }
                                    val file = withContext(Dispatchers.IO) {
                                        repository.saveTemplatePng("tpl_${System.currentTimeMillis() % 100000}", cropped)
                                    }
                                    if (mode == WizardPickMode.CropImage) cropped.recycle()
                                    steps.add(
                                        ScriptStep.ClickImage(
                                            repository.templateScriptPath(file),
                                            0.82f,
                                            10000L,
                                            0.85f,
                                            1.15f,
                                        ),
                                    )
                                    pickMode = null
                                    captureBitmap?.recycle()
                                    captureBitmap = null
                                    snackbar.showSnackbar("已添加识图步骤")
                                }
                            }
                        }
                    },
                    onCancel = {
                        pickMode = null
                        captureBitmap?.recycle()
                        captureBitmap = null
                    },
                )
            }

            Button(
                onClick = {
                    scope.launch {
                        try {
                            val json = ScriptJsonBuilder.build(
                                id = scriptName,
                                name = scriptName,
                                description = "向导创建",
                                steps = steps.toList(),
                            )
                            repository.saveNamedScript(scriptName, json)
                            onSaved()
                            snackbar.showSnackbar("已保存")
                        } catch (e: Exception) {
                            snackbar.showSnackbar("保存失败: ${e.message}")
                        }
                    }
                },
                enabled = steps.isNotEmpty(),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(Icons.Rounded.Save, contentDescription = null)
                Text("保存脚本")
            }
        }
    }

    if (showAppPicker) {
        AppPickerDialog(
            onDismiss = { showAppPicker = false },
            onSelect = { pkg, _ ->
                steps.add(0, ScriptStep.Launch(pkg))
                showAppPicker = false
            },
        )
    }

    if (showWaitDialog) {
        AlertDialog(
            onDismissRequest = { showWaitDialog = false },
            title = { Text("等待") },
            text = {
                OutlinedTextField(
                    value = waitMs,
                    onValueChange = { waitMs = it },
                    label = { Text("毫秒") },
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    val ms = waitMs.toLongOrNull() ?: 1000L
                    steps.add(ScriptStep.Wait(ms))
                    showWaitDialog = false
                }) { Text("添加") }
            },
            dismissButton = {
                TextButton(onClick = { showWaitDialog = false }) { Text("取消") }
            },
        )
    }
}

private enum class WizardPickMode {
    TapPoint,
    CropImage,
    ConfirmImageTemplate,
}

@Composable
private fun PickOverlay(
    bitmap: Bitmap?,
    mode: WizardPickMode,
    cropRect: NormRect,
    tapPoint: Offset?,
    onCropChange: (NormRect) -> Unit,
    onTap: (Float, Float) -> Unit,
    onConfirm: () -> Unit,
    onCancel: () -> Unit,
) {
    if (bitmap == null) return
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            when (mode) {
                WizardPickMode.TapPoint -> "手指点一下目标位置，点确定"
                WizardPickMode.CropImage -> "拖动框选小块区域，点确定"
                WizardPickMode.ConfirmImageTemplate -> "确认识图模板，点确定"
            },
            style = MaterialTheme.typography.labelLarge,
        )
        BoxWithSelector(
            bitmap = bitmap,
            mode = mode,
            cropRect = cropRect,
            tapPoint = tapPoint,
            onCropChange = onCropChange,
            onTap = onTap,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onCancel, modifier = Modifier.weight(1f)) { Text("取消") }
            Button(onClick = onConfirm, modifier = Modifier.weight(1f)) { Text("确定") }
        }
    }
}

@Composable
private fun BoxWithSelector(
    bitmap: Bitmap,
    mode: WizardPickMode,
    cropRect: NormRect,
    tapPoint: Offset?,
    onCropChange: (NormRect) -> Unit,
    onTap: (Float, Float) -> Unit,
) {
    androidx.compose.foundation.layout.Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(280.dp),
    ) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = null,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Fit,
        )
        TouchRectSelector(
            modifier = Modifier.fillMaxSize(),
            imageWidth = bitmap.width,
            imageHeight = bitmap.height,
            rect = cropRect,
            onRectChange = onCropChange,
            mode = if (mode == WizardPickMode.TapPoint) TouchSelectMode.TapPoint else TouchSelectMode.CropRect,
            tapPoint = tapPoint,
            onTapPoint = onTap,
        )
    }
}
