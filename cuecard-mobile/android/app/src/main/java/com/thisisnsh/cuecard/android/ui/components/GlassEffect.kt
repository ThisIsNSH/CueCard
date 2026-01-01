package com.thisisnsh.cuecard.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.dp

/**
 * Glass effect modifier that creates a frosted glass appearance
 * Similar to iOS's ultraThinMaterial with gradient overlay
 */
@Composable
fun Modifier.glassEffect(
    shape: Shape = RoundedCornerShape(50),
    isDark: Boolean = isSystemInDarkTheme()
): Modifier {
    val backgroundColor = if (isDark) {
        Color.White.copy(alpha = 0.08f)
    } else {
        Color.Black.copy(alpha = 0.05f)
    }

    val borderColor = if (isDark) {
        Color.White.copy(alpha = 0.15f)
    } else {
        Color.Black.copy(alpha = 0.1f)
    }

    val gradientColors = if (isDark) {
        listOf(
            Color.White.copy(alpha = 0.08f),
            Color.White.copy(alpha = 0.05f),
            Color.White.copy(alpha = 0.02f),
            Color.Transparent,
            Color.Transparent,
            Color.Transparent
        )
    } else {
        listOf(
            Color.Black.copy(alpha = 0.06f),
            Color.Black.copy(alpha = 0.04f),
            Color.Black.copy(alpha = 0.02f),
            Color.Transparent,
            Color.Transparent,
            Color.Transparent
        )
    }

    return this
        .clip(shape)
        .background(backgroundColor, shape)
        .background(
            brush = Brush.linearGradient(gradientColors),
            shape = shape
        )
        .border(
            width = 0.7.dp,
            color = borderColor,
            shape = shape
        )
}

/**
 * Glass effect specifically for capsule/pill shapes
 */
@Composable
fun Modifier.capsuleGlassEffect(
    isDark: Boolean = isSystemInDarkTheme()
): Modifier = glassEffect(
    shape = RoundedCornerShape(50),
    isDark = isDark
)

/**
 * Glass effect specifically for circular shapes
 */
@Composable
fun Modifier.circleGlassEffect(
    isDark: Boolean = isSystemInDarkTheme()
): Modifier = glassEffect(
    shape = CircleShape,
    isDark = isDark
)

/**
 * Glass surface composable that wraps content with glass effect
 */
@Composable
fun GlassSurface(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(50),
    isDark: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    Box(
        modifier = modifier.glassEffect(shape = shape, isDark = isDark)
    ) {
        content()
    }
}
