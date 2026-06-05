package com.moe.auto.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.moe.auto.SchedulePlanner
import com.moe.auto.ScheduleRepeat
import com.moe.auto.ScheduleRepository
import com.moe.auto.ScheduleTimeCalculator
import com.moe.auto.ScheduledTask
import com.moe.auto.ScriptEntry
import com.moe.auto.ScriptSource
import java.util.Calendar
import java.util.UUID

private enum class ScheduleTargetType {
    Script,
    App,
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScheduleListScreen(
    scripts: List<ScriptEntry>,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val repo = remember { ScheduleRepository(context) }
    val tasks = remember { mutableStateListOf<ScheduledTask>() }
    var showEditor by remember { mutableStateOf(false) }
    var editingTask by remember { mutableStateOf<ScheduledTask?>(null) }

    fun reload() {
        tasks.clear()
        tasks.addAll(repo.listAll())
    }

    LaunchedEffect(Unit) { reload() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("定时任务") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "返回")
                    }
                },
                actions = {
                    IconButton(onClick = {
                        editingTask = null
                        showEditor = true
                    }) {
                        Icon(Icons.Rounded.Add, contentDescription = "新建")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 20.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                "到点自动运行脚本或打开应用，支持每天 / 每周 / 仅一次。重启后会自动恢复排程。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (!SchedulePlanner.canScheduleExactAlarms(context)) {
                OutlinedButton(
                    onClick = { SchedulePlanner.openExactAlarmSettings(context) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("授予精确闹钟权限")
                }
            }
            if (tasks.isEmpty()) {
                Text("暂无定时任务，点右上角 + 创建")
            } else {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(tasks, key = { it.id }) { task ->
                        ScheduleTaskRow(
                            task = task,
                            onToggle = { enabled ->
                                val updated = task.copy(enabled = enabled)
                                repo.upsert(updated)
                                if (enabled) SchedulePlanner.schedule(context, updated)
                                else SchedulePlanner.cancel(context, task.id)
                                reload()
                            },
                            onDelete = {
                                SchedulePlanner.cancel(context, task.id)
                                repo.delete(task.id)
                                reload()
                            },
                            onEdit = {
                                editingTask = task
                                showEditor = true
                            },
                        )
                    }
                }
            }
        }
    }

    if (showEditor) {
        ScheduleEditorDialog(
            scripts = scripts,
            initial = editingTask,
            onDismiss = { showEditor = false },
            onSave = { task ->
                val withNext = task.copy(
                    nextRunAtMs = ScheduleTimeCalculator.computeNextRunMs(task),
                )
                repo.upsert(withNext)
                SchedulePlanner.schedule(context, withNext)
                showEditor = false
                reload()
            },
        )
    }
}

@Composable
private fun ScheduleTaskRow(
    task: ScheduledTask,
    onToggle: (Boolean) -> Unit,
    onDelete: () -> Unit,
    onEdit: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        onClick = onEdit,
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(task.name, fontWeight = FontWeight.Medium)
                val targetPrefix = if (task.scriptSourceType == "app") "应用" else "脚本"
                Text("$targetPrefix: ${task.scriptDisplayName}", style = MaterialTheme.typography.bodySmall)
                Text(
                    repeatLabel(task) + " · 下次 " + ScheduleTimeCalculator.formatNextRun(task.nextRunAtMs),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(checked = task.enabled, onCheckedChange = onToggle)
            IconButton(onClick = onDelete) {
                Icon(Icons.Rounded.Delete, contentDescription = "删除")
            }
        }
    }
}

private fun repeatLabel(task: ScheduledTask): String = when (task.repeat) {
    ScheduleRepeat.DAILY -> "每天 ${task.hour}:${"%02d".format(task.minute)}"
    ScheduleRepeat.WEEKLY -> "每周 ${weekDaysLabel(task.weekDays)} ${task.hour}:${"%02d".format(task.minute)}"
    ScheduleRepeat.ONCE -> "仅一次 ${task.hour}:${"%02d".format(task.minute)}"
}

private fun weekDaysLabel(days: List<Int>): String {
    val names = mapOf(
        Calendar.MONDAY to "一",
        Calendar.TUESDAY to "二",
        Calendar.WEDNESDAY to "三",
        Calendar.THURSDAY to "四",
        Calendar.FRIDAY to "五",
        Calendar.SATURDAY to "六",
        Calendar.SUNDAY to "日",
    )
    return days.sorted().joinToString("") { names[it] ?: "" }
}

@Composable
private fun ScheduleEditorDialog(
    scripts: List<ScriptEntry>,
    initial: ScheduledTask?,
    onDismiss: () -> Unit,
    onSave: (ScheduledTask) -> Unit,
) {
    var targetType by remember(initial) {
        mutableStateOf(if (initial?.scriptSourceType == "app") ScheduleTargetType.App else ScheduleTargetType.Script)
    }
    var name by remember(initial) { mutableStateOf(initial?.name ?: "定时任务") }
    var selectedScriptId by remember(initial, scripts) {
        mutableStateOf(initial?.scriptRef ?: scripts.firstOrNull()?.let { scriptRef(it) } ?: "")
    }
    var selectedAppPackage by remember(initial) {
        mutableStateOf(if (initial?.scriptSourceType == "app") initial.scriptRef else "")
    }
    var selectedAppLabel by remember(initial) {
        mutableStateOf(if (initial?.scriptSourceType == "app") initial.scriptDisplayName else "")
    }
    var hour by remember(initial) { mutableStateOf((initial?.hour ?: 8).toString()) }
    var minute by remember(initial) { mutableStateOf((initial?.minute ?: 0).toString()) }
    var repeat by remember(initial) { mutableStateOf(initial?.repeat ?: ScheduleRepeat.DAILY) }
    var weekDays by remember(initial) {
        mutableStateOf(initial?.weekDays?.toSet() ?: setOf(Calendar.MONDAY))
    }
    var showAppPicker by remember { mutableStateOf(false) }
    var validationError by remember { mutableStateOf<String?>(null) }

    val scriptOptions = scripts.associate { scriptRef(it) to it.name }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (initial == null) "新建定时任务" else "编辑定时任务") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("任务名称") },
                    modifier = Modifier.fillMaxWidth(),
                )
                Text("目标类型", style = MaterialTheme.typography.labelMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(
                        selected = targetType == ScheduleTargetType.Script,
                        onClick = { targetType = ScheduleTargetType.Script },
                        label = { Text("运行脚本") },
                    )
                    FilterChip(
                        selected = targetType == ScheduleTargetType.App,
                        onClick = { targetType = ScheduleTargetType.App },
                        label = { Text("打开应用") },
                    )
                }
                if (targetType == ScheduleTargetType.Script) {
                    Text("选择脚本", style = MaterialTheme.typography.labelMedium)
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        scriptOptions.forEach { (ref, display) ->
                            FilterChip(
                                selected = selectedScriptId == ref,
                                onClick = { selectedScriptId = ref },
                                label = { Text(display) },
                            )
                        }
                    }
                } else {
                    Text("选择应用", style = MaterialTheme.typography.labelMedium)
                    OutlinedButton(
                        onClick = { showAppPicker = true },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(if (selectedAppPackage.isBlank()) "从已安装应用中选择" else "重新选择应用")
                    }
                    if (selectedAppPackage.isNotBlank()) {
                        Text(
                            "$selectedAppLabel ($selectedAppPackage)",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = hour,
                        onValueChange = { hour = it },
                        label = { Text("时") },
                        modifier = Modifier.weight(1f),
                    )
                    OutlinedTextField(
                        value = minute,
                        onValueChange = { minute = it },
                        label = { Text("分") },
                        modifier = Modifier.weight(1f),
                    )
                }
                Text("重复", style = MaterialTheme.typography.labelMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(
                        selected = repeat == ScheduleRepeat.DAILY,
                        onClick = { repeat = ScheduleRepeat.DAILY },
                        label = { Text("每天") },
                    )
                    FilterChip(
                        selected = repeat == ScheduleRepeat.WEEKLY,
                        onClick = { repeat = ScheduleRepeat.WEEKLY },
                        label = { Text("每周") },
                    )
                    FilterChip(
                        selected = repeat == ScheduleRepeat.ONCE,
                        onClick = { repeat = ScheduleRepeat.ONCE },
                        label = { Text("一次") },
                    )
                }
                if (repeat == ScheduleRepeat.WEEKLY) {
                    val dayOptions = listOf(
                        Calendar.MONDAY to "一",
                        Calendar.TUESDAY to "二",
                        Calendar.WEDNESDAY to "三",
                        Calendar.THURSDAY to "四",
                        Calendar.FRIDAY to "五",
                        Calendar.SATURDAY to "六",
                        Calendar.SUNDAY to "日",
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        dayOptions.forEach { (dow, label) ->
                            FilterChip(
                                selected = weekDays.contains(dow),
                                onClick = {
                                    weekDays = if (weekDays.contains(dow)) {
                                        weekDays - dow
                                    } else {
                                        weekDays + dow
                                    }
                                },
                                label = { Text(label) },
                            )
                        }
                    }
                }
                validationError?.let { msg ->
                    Text(
                        msg,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val h = hour.toIntOrNull()?.coerceIn(0, 23) ?: 8
                val m = minute.toIntOrNull()?.coerceIn(0, 59) ?: 0
                val target = when (targetType) {
                    ScheduleTargetType.Script -> {
                        if (selectedScriptId.isBlank()) {
                            validationError = "请先选择脚本"
                            return@TextButton
                        }
                        parseScriptRef(selectedScriptId, scriptOptions)
                    }
                    ScheduleTargetType.App -> {
                        if (selectedAppPackage.isBlank()) {
                            validationError = "请先选择应用"
                            return@TextButton
                        }
                        Triple(
                            "app",
                            selectedAppPackage,
                            selectedAppLabel.ifBlank { selectedAppPackage },
                        )
                    }
                }
                validationError = null
                val task = ScheduledTask(
                    id = initial?.id ?: UUID.randomUUID().toString(),
                    name = name.trim().ifBlank { "定时任务" },
                    enabled = true,
                    scriptSourceType = target.first,
                    scriptRef = target.second,
                    scriptDisplayName = target.third,
                    hour = h,
                    minute = m,
                    repeat = repeat,
                    weekDays = if (repeat == ScheduleRepeat.WEEKLY) weekDays.sorted().toList() else emptyList(),
                )
                onSave(task)
            }) { Text("保存") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
    )

    if (showAppPicker) {
        AppPickerDialog(
            onDismiss = { showAppPicker = false },
            onSelect = { pkg, label ->
                selectedAppPackage = pkg
                selectedAppLabel = label
                showAppPicker = false
            },
        )
    }
}

private fun scriptRef(entry: ScriptEntry): String = when (val src = entry.source) {
    is ScriptSource.Asset -> "asset:${src.path}"
    is ScriptSource.UserFile -> "file:${src.file.absolutePath}"
}

private fun parseScriptRef(
    key: String,
    names: Map<String, String>,
): Triple<String, String, String> {
    val display = names[key] ?: key
    return when {
        key.startsWith("asset:") -> Triple("asset", key.removePrefix("asset:"), display)
        key.startsWith("file:") -> Triple("file", key.removePrefix("file:"), display)
        else -> Triple("asset", key, display)
    }
}
