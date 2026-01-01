package com.thisisnsh.cuecard.android.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.analytics.ktx.analytics
import com.google.firebase.analytics.logEvent
import com.google.firebase.ktx.Firebase
import com.thisisnsh.cuecard.android.services.SettingsService
import com.thisisnsh.cuecard.android.ui.components.glassEffect
import com.thisisnsh.cuecard.android.ui.theme.AppColors
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    settingsService: SettingsService,
    onNavigateToSettings: () -> Unit,
    onNavigateToTeleprompter: () -> Unit
) {
    val settings by settingsService.settings.collectAsState()
    val notes by settingsService.notes.collectAsState()
    val scope = rememberCoroutineScope()
    val isDark = isSystemInDarkTheme()
    val focusManager = LocalFocusManager.current

    var showTimerPicker by remember { mutableStateOf(false) }
    var localNotes by remember { mutableStateOf(notes) }

    // Sync local notes with service
    LaunchedEffect(notes) {
        localNotes = notes
    }

    // Log screen view
    LaunchedEffect(Unit) {
        Firebase.analytics.logEvent("screen_view") {
            param("screen_name", "home")
        }
        settingsService.loadSettings()
    }

    val hasNotes = localNotes.trim().isNotEmpty()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.background(isDark))
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Top App Bar
            TopAppBar(
                title = {
                    Text(
                        text = "CueCard",
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.textPrimary(isDark)
                    )
                },
                actions = {
                    IconButton(onClick = onNavigateToSettings) {
                        Icon(
                            imageVector = Icons.Default.Settings,
                            contentDescription = "Settings",
                            tint = AppColors.textPrimary(isDark)
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = AppColors.background(isDark)
                )
            )

            // Notes Editor
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) {
                BasicTextField(
                    value = localNotes,
                    onValueChange = { newValue ->
                        localNotes = newValue
                        scope.launch {
                            settingsService.saveNotes(newValue)
                        }
                    },
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(vertical = 8.dp),
                    textStyle = TextStyle(
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        color = AppColors.textPrimary(isDark),
                        lineHeight = 24.sp
                    ),
                    cursorBrush = SolidColor(AppColors.green(isDark)),
                    decorationBox = { innerTextField ->
                        Box {
                            if (localNotes.isEmpty()) {
                                Text(
                                    text = "Paste your script here...\n\nUse [note text] for delivery cues\nSet timer duration below",
                                    fontSize = 16.sp,
                                    color = AppColors.textSecondary(isDark).copy(alpha = 0.6f),
                                    lineHeight = 24.sp
                                )
                            }
                            innerTextField()
                        }
                    }
                )
            }

            // Bottom Controls
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .padding(bottom = 24.dp)
                    .imePadding()
            ) {
                // Timer Picker (animated)
                AnimatedVisibility(
                    visible = showTimerPicker,
                    enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
                    exit = slideOutVertically(targetOffsetY = { it }) + fadeOut()
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 12.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(AppColors.background(isDark))
                            .border(
                                width = 1.dp,
                                color = AppColors.textSecondary(isDark).copy(alpha = 0.2f),
                                shape = RoundedCornerShape(16.dp)
                            )
                            .padding(12.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Timer",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = AppColors.textPrimary(isDark)
                            )
                            IconButton(
                                onClick = { showTimerPicker = false },
                                modifier = Modifier
                                    .size(28.dp)
                                    .clip(CircleShape)
                                    .background(AppColors.background(isDark).copy(alpha = 0.85f))
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Close,
                                    contentDescription = "Close",
                                    modifier = Modifier.size(14.dp),
                                    tint = AppColors.textSecondary(isDark)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Duration",
                                color = AppColors.textSecondary(isDark)
                            )

                            Row(
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                // Minutes picker
                                NumberPicker(
                                    value = settings.timerMinutes,
                                    range = 0..59,
                                    onValueChange = { newValue ->
                                        scope.launch {
                                            settingsService.updateTimerMinutes(newValue)
                                        }
                                    },
                                    isDark = isDark
                                )

                                Text(
                                    text = ":",
                                    fontSize = 16.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = AppColors.textSecondary(isDark),
                                    modifier = Modifier.padding(horizontal = 8.dp)
                                )

                                // Seconds picker
                                NumberPicker(
                                    value = settings.timerSeconds,
                                    range = 0..59,
                                    onValueChange = { newValue ->
                                        scope.launch {
                                            settingsService.updateTimerSeconds(newValue)
                                        }
                                    },
                                    isDark = isDark,
                                    formatValue = { String.format("%02d", it) }
                                )
                            }
                        }
                    }
                }

                // Bottom Row: Timer Button + Play Button
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.Bottom
                ) {
                    // Set Timer Button
                    Box(
                        modifier = Modifier
                            .height(52.dp)
                            .clip(RoundedCornerShape(50))
                            .glassEffect(isDark = isDark)
                            .clickable { showTimerPicker = !showTimerPicker }
                            .padding(horizontal = 16.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = if (showTimerPicker) "Done" else "Set Timer",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = AppColors.textPrimary(isDark)
                        )
                    }

                    Spacer(modifier = Modifier.width(12.dp))

                    // Play Button
                    Box(
                        modifier = Modifier
                            .size(52.dp)
                            .clip(CircleShape)
                            .background(
                                if (hasNotes) AppColors.green(isDark)
                                else AppColors.green(isDark).copy(alpha = 0.6f)
                            )
                            .glassEffect(shape = CircleShape, isDark = isDark)
                            .clickable(enabled = hasNotes) {
                                focusManager.clearFocus()
                                onNavigateToTeleprompter()
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.PlayArrow,
                            contentDescription = "Start Teleprompter",
                            modifier = Modifier.size(24.dp),
                            tint = if (isDark) Color.Black else Color.White
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun NumberPicker(
    value: Int,
    range: IntRange,
    onValueChange: (Int) -> Unit,
    isDark: Boolean,
    formatValue: (Int) -> String = { it.toString() }
) {
    Row(
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Decrease button
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(AppColors.textSecondary(isDark).copy(alpha = 0.1f))
                .clickable {
                    if (value > range.first) {
                        onValueChange(value - 1)
                    }
                },
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "-",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.textPrimary(isDark)
            )
        }

        // Value display
        Text(
            text = formatValue(value),
            fontSize = 20.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.textPrimary(isDark),
            modifier = Modifier.padding(horizontal = 16.dp)
        )

        // Increase button
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(AppColors.textSecondary(isDark).copy(alpha = 0.1f))
                .clickable {
                    if (value < range.last) {
                        onValueChange(value + 1)
                    }
                },
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "+",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.textPrimary(isDark)
            )
        }
    }
}
