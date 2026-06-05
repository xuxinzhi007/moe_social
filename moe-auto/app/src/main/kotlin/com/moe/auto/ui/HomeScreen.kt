package com.moe.auto.ui

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.view.accessibility.AccessibilityManager
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Accessibility
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.moe.auto.AutoBridge
import com.moe.auto.MoeAutoAccessibilityService

data class ScriptItem(
    val title: String,
    val description: String,
    val assetPath: String,
)

private val demoScripts = listOf(
    ScriptItem(
        title = "桌面滑动 + Home",
        description = "回到桌面并上滑，演示坐标滑动",
        assetPath = "scripts/demo_tap_swipe.json",
    ),
    ScriptItem(
        title = "打开系统设置",
        description = "启动 com.android.settings",
        assetPath = "scripts/open_settings.json",
    ),
)

@Composable
fun HomeScreen(
    onOpenAccessibilitySettings: () -> Unit,
    onOpenOverlaySettings: () -> Unit,
    onRunScript: (String) -> Unit,
    onStopScript: () -> Unit,
) {
    val context = LocalContext.current
    val logs by AutoBridge.logs.collectAsState()
    val running by AutoBridge.running.collectAsState()
    var a11yEnabled by remember { mutableStateOf(isAccessibilityEnabled(context)) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = "Moe Auto",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary,
        )
        Text(
            text = "免 Root 自动化 · JSON 脚本 · 对标自动精灵 / 按键精灵",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f),
        )

        PermissionCard(
            title = "无障碍服务",
            subtitle = if (a11yEnabled) "已开启" else "必须开启才能点击/滑动",
            actionLabel = if (a11yEnabled) "重新检查" else "去开启",
            onAction = {
                onOpenAccessibilitySettings()
                a11yEnabled = isAccessibilityEnabled(context)
            },
            icon = Icons.Rounded.Accessibility,
        )

        OutlinedButton(onClick = onOpenOverlaySettings, modifier = Modifier.fillMaxWidth()) {
            Text("悬浮窗权限（可选）")
        }

        Text(
            text = "示例脚本",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )

        demoScripts.forEach { script ->
            ScriptCard(
                item = script,
                running = running,
                enabled = a11yEnabled,
                onRun = { onRunScript(script.assetPath) },
            )
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
                Text("停止")
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
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
        ) {
            LazyColumn(
                modifier = Modifier.padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                if (logs.isEmpty()) {
                    item {
                        Text(
                            "暂无日志。开启无障碍后选择脚本运行。",
                            style = MaterialTheme.typography.bodySmall,
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

@Composable
private fun PermissionCard(
    title: String,
    subtitle: String,
    actionLabel: String,
    onAction: () -> Unit,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.SemiBold)
                Text(subtitle, style = MaterialTheme.typography.bodySmall)
            }
            OutlinedButton(onClick = onAction) {
                Text(actionLabel)
            }
        }
    }
}

@Composable
private fun ScriptCard(
    item: ScriptItem,
    running: Boolean,
    enabled: Boolean,
    onRun: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(item.title, fontWeight = FontWeight.Medium)
                Spacer(modifier = Modifier.height(4.dp))
                Text(item.description, style = MaterialTheme.typography.bodySmall)
            }
            Button(
                onClick = onRun,
                enabled = enabled && !running,
            ) {
                Icon(Icons.Rounded.PlayArrow, contentDescription = null)
                Text("运行")
            }
        }
    }
}

private fun isAccessibilityEnabled(context: android.content.Context): Boolean {
    val am = context.getSystemService(android.content.Context.ACCESSIBILITY_SERVICE)
        as AccessibilityManager
    val expected = ComponentName(context, MoeAutoAccessibilityService::class.java)
    val enabled = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
    return enabled.any { it.resolveInfo.serviceInfo.let { s -> ComponentName(s.packageName, s.name) == expected } }
}
