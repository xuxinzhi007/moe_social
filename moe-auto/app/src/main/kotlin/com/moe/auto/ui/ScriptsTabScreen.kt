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
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.FileOpen
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.moe.auto.AutoBridge
import com.moe.auto.ScriptEntry
import com.moe.auto.ScriptSource

@Composable
fun ScriptsTabScreen(
    modifier: Modifier = Modifier,
    scripts: List<ScriptEntry>,
    a11yEnabled: Boolean,
    onCreateScript: () -> Unit,
    onImportScript: () -> Unit,
    onEditScript: (ScriptEntry) -> Unit,
    onDeleteScript: (ScriptEntry) -> Unit,
    onRunScript: (ScriptEntry) -> Unit,
    onOpenWizard: () -> Unit,
    onOpenSchedules: () -> Unit,
) {
    val running by AutoBridge.running.collectAsState()
    val canRun = a11yEnabled && !running

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = "脚本库",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = "新建、导入或编辑 JSON 自动化脚本",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            OutlinedButton(onClick = onCreateScript, modifier = Modifier.weight(1f)) {
                Icon(Icons.Rounded.Add, contentDescription = null)
                Text("新建")
            }
            OutlinedButton(onClick = onImportScript, modifier = Modifier.weight(1f)) {
                Icon(Icons.Rounded.FileOpen, contentDescription = null)
                Text("导入")
            }
        }
        Button(onClick = onOpenWizard, modifier = Modifier.fillMaxWidth()) {
            Icon(Icons.Rounded.AutoAwesome, contentDescription = null)
            Text("向导创建（点选 / 框选 / 流程图）")
        }
        OutlinedButton(onClick = onOpenSchedules, modifier = Modifier.fillMaxWidth()) {
            Icon(Icons.Rounded.Schedule, contentDescription = null)
            Text("定时任务")
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(scripts, key = { it.id + it.name }) { script ->
                ScriptListRow(
                    entry = script,
                    canRun = canRun,
                    isUser = script.source is ScriptSource.UserFile,
                    onRun = { onRunScript(script) },
                    onEdit = { onEditScript(script) },
                    onDelete = { onDeleteScript(script) },
                )
            }
        }
    }
}

@Composable
private fun ScriptListRow(
    entry: ScriptEntry,
    canRun: Boolean,
    isUser: Boolean,
    onRun: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(entry.name, fontWeight = FontWeight.Medium)
                Text(entry.description, style = MaterialTheme.typography.bodySmall)
            }
            if (isUser) {
                IconButton(onClick = onEdit) {
                    Icon(Icons.Rounded.Edit, contentDescription = "编辑")
                }
                IconButton(onClick = onDelete) {
                    Icon(Icons.Rounded.Delete, contentDescription = "删除")
                }
            }
            Button(onClick = onRun, enabled = canRun) {
                Icon(Icons.Rounded.PlayArrow, contentDescription = null)
            }
        }
    }
}
