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
import androidx.compose.material.icons.rounded.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.moe.auto.AutoBridge

@Composable
fun RunTabScreen(
    modifier: Modifier = Modifier,
    onStopScript: () -> Unit,
) {
    val logs by AutoBridge.logs.collectAsState()
    val running by AutoBridge.running.collectAsState()
    val progress by AutoBridge.runProgress.collectAsState()

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = "运行中心",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
        )

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(14.dp),
            colors = CardDefaults.cardColors(
                containerColor = if (running) {
                    MaterialTheme.colorScheme.primaryContainer
                } else {
                    MaterialTheme.colorScheme.surfaceVariant
                },
            ),
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = if (running) "任务执行中" else "空闲",
                    fontWeight = FontWeight.SemiBold,
                )
                if (running && progress != null) {
                    val p = progress!!
                    Text(
                        text = p.scriptName,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                    Text(
                        text = p.stepLabel,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                    )
                    Text(
                        text = if (p.loopTotal > 1) {
                            "第 ${p.loopIndex}/${p.loopTotal} 轮 · 步骤 ${p.stepIndex}/${p.stepTotal}"
                        } else {
                            "步骤 ${p.stepIndex} / ${p.stepTotal}"
                        },
                        style = MaterialTheme.typography.bodySmall,
                    )
                    if (p.stepTotal > 0) {
                        LinearProgressIndicator(
                            progress = { p.stepIndex.toFloat() / p.stepTotal.toFloat() },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                } else {
                    Text(
                        text = if (running) "可在通知栏或下方停止任务" else "在「脚本」页选择任务并运行",
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Button(
                onClick = onStopScript,
                enabled = running,
                modifier = Modifier.weight(1f),
            ) {
                Icon(Icons.Rounded.Stop, contentDescription = null)
                Text("停止任务")
            }
            OutlinedButton(
                onClick = { AutoBridge.clearLogs() },
                modifier = Modifier.weight(1f),
            ) {
                Text("清空日志")
            }
        }

        Text(
            text = "运行日志",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )

        Card(
            modifier = Modifier.fillMaxSize(),
            shape = RoundedCornerShape(16.dp),
        ) {
            LazyColumn(
                modifier = Modifier.padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                if (logs.isEmpty()) {
                    item {
                        Text(
                            "暂无日志。运行脚本后步骤输出会显示在这里。",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                } else {
                    items(logs) { line ->
                        Text(line, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
    }
}
