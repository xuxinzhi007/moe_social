package com.moe.auto.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.moe.auto.SchedulePlanner
import com.moe.auto.UserSettings

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdvancedSettingsScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val settings = remember { UserSettings.get(context) }
    var overlayEnabled by remember { mutableStateOf(settings.executionOverlayEnabled) }
    var notifStep by remember { mutableStateOf(settings.showNotificationStep) }
    val exactAlarmOk = remember { SchedulePlanner.canScheduleExactAlarms(context) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("高级设置") },
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
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            SettingSwitchRow(
                title = "屏幕点击指示",
                subtitle = "运行时显示点击圆点与滑动轨迹（默认开启）",
                checked = overlayEnabled,
                onCheckedChange = {
                    overlayEnabled = it
                    settings.executionOverlayEnabled = it
                },
            )
            SettingSwitchRow(
                title = "通知栏显示当前步骤",
                subtitle = "在通知中更新步骤进度（默认关闭，避免刷屏）",
                checked = notifStep,
                onCheckedChange = {
                    notifStep = it
                    settings.showNotificationStep = it
                },
            )
            Text(
                "运行 Tab 始终显示当前步骤；跨 App 时以屏幕指示为主。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (!exactAlarmOk) {
                Text(
                    "定时任务需要「精确闹钟」权限，请在系统设置中允许。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
                androidx.compose.material3.OutlinedButton(
                    onClick = { SchedulePlanner.openExactAlarmSettings(context) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("打开精确闹钟设置")
                }
            }
        }
    }
}

@Composable
private fun SettingSwitchRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    androidx.compose.foundation.layout.Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = 12.dp)) {
            Text(title, fontWeight = FontWeight.Medium)
            Text(subtitle, style = MaterialTheme.typography.bodySmall)
        }
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
