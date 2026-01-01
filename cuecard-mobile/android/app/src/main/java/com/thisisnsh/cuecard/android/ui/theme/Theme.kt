package com.thisisnsh.cuecard.android.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val DarkColorScheme = darkColorScheme(
    primary = AppColors.Dark.green,
    secondary = AppColors.Dark.pink,
    tertiary = AppColors.Dark.yellow,
    background = AppColors.Dark.background,
    surface = AppColors.Dark.background,
    onPrimary = AppColors.Dark.background,
    onSecondary = AppColors.Dark.textPrimary,
    onTertiary = AppColors.Dark.background,
    onBackground = AppColors.Dark.textPrimary,
    onSurface = AppColors.Dark.textPrimary,
    error = AppColors.Dark.red,
    onError = AppColors.Dark.textPrimary
)

private val LightColorScheme = lightColorScheme(
    primary = AppColors.Light.green,
    secondary = AppColors.Light.pink,
    tertiary = AppColors.Light.yellow,
    background = AppColors.Light.background,
    surface = AppColors.Light.background,
    onPrimary = AppColors.Light.background,
    onSecondary = AppColors.Light.textPrimary,
    onTertiary = AppColors.Light.background,
    onBackground = AppColors.Light.textPrimary,
    onSurface = AppColors.Light.textPrimary,
    error = AppColors.Light.red,
    onError = AppColors.Light.textPrimary
)

@Composable
fun CueCardTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.background.toArgb()
            window.navigationBarColor = colorScheme.background.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
            WindowCompat.getInsetsController(window, view).isAppearanceLightNavigationBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        content = content
    )
}
