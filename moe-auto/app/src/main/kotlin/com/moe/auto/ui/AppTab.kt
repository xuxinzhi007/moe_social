package com.moe.auto.ui

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AccountCircle
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.PlayCircle
import androidx.compose.ui.graphics.vector.ImageVector

enum class AppTab(
    val label: String,
    val icon: ImageVector,
) {
    Scripts("脚本", Icons.Rounded.Description),
    Run("运行", Icons.Rounded.PlayCircle),
    Profile("我的", Icons.Rounded.AccountCircle),
}
