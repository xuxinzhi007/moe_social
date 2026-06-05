package com.moe.auto.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Code
import androidx.compose.material.icons.rounded.Launch
import androidx.compose.material.icons.rounded.Save
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.moe.auto.ScriptJsonBuilder
import com.moe.auto.ScriptParser
import com.moe.auto.ScriptRepository
import com.moe.auto.ScriptStep
import kotlinx.coroutines.launch
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScriptVisualEditorScreen(
    file: File,
    repository: ScriptRepository,
    onBack: () -> Unit,
    onOpenJsonEditor: () -> Unit,
) {
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val steps = remember { mutableStateListOf<ScriptStep>() }
    var scriptName by remember { mutableStateOf(file.nameWithoutExtension) }
    var scriptDesc by remember { mutableStateOf("") }
    var showAppPicker by remember { mutableStateOf(false) }
    var showWaitDialog by remember { mutableStateOf(false) }
    var showEditDialog by remember { mutableStateOf<ScriptStep?>(null) }
    var editIndex by remember { mutableStateOf(-1) }
    var waitMs by remember { mutableStateOf("1000") }

    LaunchedEffect(file.absolutePath) {
        if (!file.exists()) return@LaunchedEffect
        val script = ScriptParser.parse(file.readText())
        scriptName = script.name
        scriptDesc = script.id
        steps.clear()
        steps.addAll(script.steps)
    }

    fun save() {
        scope.launch {
            try {
                val json = ScriptJsonBuilder.build(
                    id = file.nameWithoutExtension,
                    name = scriptName,
                    description = scriptDesc.ifBlank { "自定义脚本" },
                    steps = steps.toList(),
                )
                repository.saveUserScript(file, json)
                snackbar.showSnackbar("已保存")
            } catch (e: Exception) {
                snackbar.showSnackbar("保存失败: ${e.message}")
            }
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text("编辑步骤") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "返回")
                    }
                },
                actions = {
                    IconButton(onClick = onOpenJsonEditor) {
                        Icon(Icons.Rounded.Code, contentDescription = "JSON")
                    }
                    IconButton(onClick = { save() }) {
                        Icon(Icons.Rounded.Save, contentDescription = "保存")
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
                "所有步骤通过无障碍在任意 App 前台执行（跨应用）。可上移/下移/删除/编辑。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            OutlinedTextField(
                value = scriptName,
                onValueChange = { scriptName = it },
                label = { Text("脚本名称") },
                modifier = Modifier.fillMaxWidth(),
            )

            Text("步骤列表", style = MaterialTheme.typography.titleSmall)
            StepListEditor(
                steps = steps,
                onMoveUp = { i -> swapSteps(steps, i, i - 1) },
                onMoveDown = { i -> swapSteps(steps, i, i + 1) },
                onDelete = { i -> steps.removeAt(i) },
                onEdit = { i ->
                    editIndex = i
                    showEditDialog = steps[i]
                },
            )

            Text("流程图", style = MaterialTheme.typography.titleSmall)
            ScriptFlowchartView(steps = steps)

            Text("添加步骤", style = MaterialTheme.typography.titleSmall)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = { showAppPicker = true }, modifier = Modifier.weight(1f)) {
                    Icon(Icons.Rounded.Launch, contentDescription = null)
                    Text("启动应用")
                }
                OutlinedButton(onClick = { showWaitDialog = true }, modifier = Modifier.weight(1f)) {
                    Text("等待")
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = { steps.add(ScriptStep.Back) },
                    modifier = Modifier.weight(1f),
                ) { Text("返回") }
                OutlinedButton(
                    onClick = { steps.add(ScriptStep.Home) },
                    modifier = Modifier.weight(1f),
                ) { Text("桌面") }
            }

            Button(onClick = { save() }, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Rounded.Save, contentDescription = null)
                Text("保存脚本")
            }
        }
    }

    if (showAppPicker) {
        AppPickerDialog(
            onDismiss = { showAppPicker = false },
            onSelect = { pkg, _ ->
                steps.add(ScriptStep.Launch(pkg))
                showAppPicker = false
            },
        )
    }

    if (showWaitDialog) {
        AlertDialog(
            onDismissRequest = { showWaitDialog = false },
            title = { Text("等待") },
            text = {
                OutlinedTextField(value = waitMs, onValueChange = { waitMs = it }, label = { Text("毫秒") })
            },
            confirmButton = {
                TextButton(onClick = {
                    steps.add(ScriptStep.Wait(waitMs.toLongOrNull() ?: 1000L))
                    showWaitDialog = false
                }) { Text("添加") }
            },
            dismissButton = {
                TextButton(onClick = { showWaitDialog = false }) { Text("取消") }
            },
        )
    }

    showEditDialog?.let { step ->
        StepEditDialog(
            step = step,
            onDismiss = { showEditDialog = null },
            onConfirm = { updated ->
                if (editIndex in steps.indices) {
                    steps[editIndex] = updated
                }
                showEditDialog = null
            },
        )
    }
}

@Composable
private fun StepEditDialog(
    step: ScriptStep,
    onDismiss: () -> Unit,
    onConfirm: (ScriptStep) -> Unit,
) {
    var waitMs by remember(step) {
        mutableStateOf((step as? ScriptStep.Wait)?.ms?.toString() ?: "1000")
    }
    var pkg by remember(step) {
        mutableStateOf((step as? ScriptStep.Launch)?.packageName ?: "")
    }
    var text by remember(step) {
        mutableStateOf(
            when (step) {
                is ScriptStep.ClickText -> step.text
                is ScriptStep.OcrClick -> step.text
                is ScriptStep.Input -> step.text
                else -> ""
            },
        )
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("编辑步骤") },
        text = {
            when (step) {
                is ScriptStep.Wait -> {
                    OutlinedTextField(value = waitMs, onValueChange = { waitMs = it }, label = { Text("毫秒") })
                }
                is ScriptStep.Launch -> {
                    var pickApp by remember(step) { mutableStateOf(false) }
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(value = pkg, onValueChange = { pkg = it }, label = { Text("包名") })
                        OutlinedButton(onClick = { pickApp = true }, modifier = Modifier.fillMaxWidth()) {
                            Text("从已安装应用选择")
                        }
                    }
                    if (pickApp) {
                        AppPickerDialog(
                            onDismiss = { pickApp = false },
                            onSelect = { selected, _ ->
                                pkg = selected
                                pickApp = false
                            },
                        )
                    }
                }
                is ScriptStep.ClickText, is ScriptStep.OcrClick, is ScriptStep.Input -> {
                    OutlinedTextField(value = text, onValueChange = { text = it }, label = { Text("文本") })
                }
                is ScriptStep.Tap -> {
                    Text("坐标点击请在向导中重新点选，或改 JSON。")
                }
                else -> Text("该步骤请使用 JSON 高级编辑。")
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val updated = when (step) {
                    is ScriptStep.Wait -> ScriptStep.Wait(waitMs.toLongOrNull() ?: 1000L)
                    is ScriptStep.Launch -> ScriptStep.Launch(pkg.trim())
                    is ScriptStep.ClickText -> step.copy(text = text, timeoutMs = step.timeoutMs)
                    is ScriptStep.OcrClick -> step.copy(text = text, timeoutMs = step.timeoutMs)
                    is ScriptStep.Input -> ScriptStep.Input(text)
                    else -> step
                }
                onConfirm(updated)
            }) { Text("确定") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
    )
}
