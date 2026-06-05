package com.moe.auto.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
fun PermissionStatusCard(
    a11yEnabled: Boolean,
    overlayGranted: Boolean,
    serviceConnected: Boolean,
    onOpenAccessibilitySettings: () -> Unit,
    onOpenOverlaySettings: () -> Unit,
    showA11yHint: Boolean = true,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            PermissionStatusLine(
                label = "无障碍服务",
                ok = a11yEnabled,
                hint = if (a11yEnabled) "已授权" else "未开启",
                action = "设置",
                onAction = onOpenAccessibilitySettings,
            )
            PermissionStatusLine(
                label = "服务连接",
                ok = serviceConnected,
                hint = when {
                    serviceConnected -> "运行中"
                    a11yEnabled -> "请重新开关服务"
                    else -> "—"
                },
                action = null,
                onAction = {},
            )
            PermissionStatusLine(
                label = "悬浮窗",
                ok = overlayGranted,
                hint = if (overlayGranted) "已授权" else "未授权（可选）",
                action = "设置",
                onAction = onOpenOverlaySettings,
            )
            if (showA11yHint) {
                Text(
                    "部分机型系统仍会显示无障碍指示，可在系统无障碍详情里关闭「无障碍按钮」。",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
fun PermissionStatusLine(
    label: String,
    ok: Boolean,
    hint: String,
    action: String?,
    onAction: () -> Unit,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = if (ok) "●" else "○",
            color = if (ok) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
        )
        Column(modifier = Modifier.weight(1f).padding(horizontal = 8.dp)) {
            Text(label, fontWeight = FontWeight.Medium)
            Text(hint, style = MaterialTheme.typography.bodySmall)
        }
        if (action != null) {
            OutlinedButton(onClick = onAction) {
                Text(action)
            }
        }
    }
}
