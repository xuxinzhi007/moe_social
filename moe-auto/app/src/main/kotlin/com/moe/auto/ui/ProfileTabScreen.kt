package com.moe.auto.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Cloud
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.ImageSearch
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
fun ProfileTabScreen(
    modifier: Modifier = Modifier,
    a11yEnabled: Boolean,
    overlayGranted: Boolean,
    serviceConnected: Boolean,
    appVersion: String,
    scriptsDirHint: String,
    onOpenAccessibilitySettings: () -> Unit,
    onOpenOverlaySettings: () -> Unit,
    onOpenVisionLab: () -> Unit,
    onOpenAdvancedSettings: () -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = "个人中心",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
        )

        PermissionStatusCard(
            a11yEnabled = a11yEnabled,
            overlayGranted = overlayGranted,
            serviceConnected = serviceConnected,
            onOpenAccessibilitySettings = onOpenAccessibilitySettings,
            onOpenOverlaySettings = onOpenOverlaySettings,
        )

        ProfileSectionTitle("功能")
        ProfileMenuItem(
            icon = Icons.Rounded.ImageSearch,
            title = "识图工具",
            subtitle = "截屏裁剪、保存模板、测试匹配",
            enabled = true,
            onClick = onOpenVisionLab,
        )
        ProfileMenuItem(
            icon = Icons.Rounded.Cloud,
            title = "云端脚本",
            subtitle = "即将推出",
            enabled = false,
            onClick = {},
        )
        ProfileMenuItem(
            icon = Icons.Rounded.History,
            title = "运行历史",
            subtitle = "即将推出",
            enabled = false,
            onClick = {},
        )
        ProfileMenuItem(
            icon = Icons.Rounded.Settings,
            title = "高级设置",
            subtitle = "点击指示、通知步骤、精确闹钟",
            enabled = true,
            onClick = onOpenAdvancedSettings,
        )

        ProfileSectionTitle("存储")
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(14.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        ) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("用户脚本目录", fontWeight = FontWeight.Medium)
                Text(
                    scriptsDirHint,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    "识图模板请放在 templates 子目录",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        ProfileSectionTitle("关于")
        ProfileMenuItem(
            icon = Icons.Rounded.Info,
            title = "Moe Auto",
            subtitle = "版本 $appVersion",
            enabled = false,
            onClick = {},
        )
    }
}

@Composable
private fun ProfileSectionTitle(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.primary,
    )
}

@Composable
private fun ProfileMenuItem(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    subtitle: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Card(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.Medium)
                Text(subtitle, style = MaterialTheme.typography.bodySmall)
            }
            if (enabled) {
                Icon(Icons.Rounded.ChevronRight, contentDescription = null)
            }
        }
    }
}
