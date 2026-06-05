package com.moe.auto.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Lavender = Color(0xFF7F7FD5)
private val SkyBlue = Color(0xFF86A8E7)
private val Mint = Color(0xFF91EAE4)
private val PageBg = Color(0xFFF5F7FA)

private val LightColors = lightColorScheme(
    primary = Lavender,
    secondary = SkyBlue,
    tertiary = Mint,
    background = PageBg,
    surface = Color.White,
)

private val DarkColors = darkColorScheme(
    primary = SkyBlue,
    secondary = Lavender,
    tertiary = Mint,
)

@Composable
fun MoeAutoTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors,
        content = content,
    )
}
