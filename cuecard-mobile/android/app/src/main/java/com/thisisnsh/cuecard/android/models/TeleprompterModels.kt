package com.thisisnsh.cuecard.android.models

import kotlinx.serialization.Serializable
import java.util.Date
import java.util.UUID

/**
 * Theme preference for the app
 */
@Serializable
enum class ThemePreference(val displayName: String) {
    SYSTEM("System"),
    LIGHT("Light"),
    DARK("Dark");

    companion object {
        fun fromString(value: String): ThemePreference {
            return entries.find { it.displayName == value } ?: SYSTEM
        }
    }
}

/**
 * Font size presets for teleprompter
 */
@Serializable
enum class FontSizePreset(val displayName: String, val fontSize: Int, val pipFontSize: Int) {
    SMALL("Small", 20, 12),
    MEDIUM("Medium", 28, 16),
    LARGE("Large", 40, 22);

    companion object {
        fun fromString(value: String): FontSizePreset {
            return entries.find { it.displayName == value } ?: MEDIUM
        }
    }
}

/**
 * Overlay dimension ratio presets
 */
@Serializable
enum class OverlayAspectRatio(val displayName: String, val ratio: Float) {
    RATIO_16X9("16:9", 16f / 9f),
    RATIO_4X3("4:3", 4f / 3f),
    RATIO_1X1("1:1", 1f);

    companion object {
        fun fromString(value: String): OverlayAspectRatio {
            return entries.find { it.displayName == value } ?: RATIO_16X9
        }
    }
}

/**
 * Settings for the teleprompter
 */
@Serializable
data class TeleprompterSettings(
    val fontSizePreset: FontSizePreset = FontSizePreset.MEDIUM,
    val pipFontSizePreset: FontSizePreset = FontSizePreset.MEDIUM,
    val overlayAspectRatio: OverlayAspectRatio = OverlayAspectRatio.RATIO_16X9,
    val scrollSpeed: Double = 1.0,
    val wordsPerMinute: Int = 150,
    val linesPerMinute: Int = 10,
    val timerMinutes: Int = 1,
    val timerSeconds: Int = 0,
    val autoScroll: Boolean = true,
    val themePreference: ThemePreference = ThemePreference.SYSTEM,
    val countdownSeconds: Int = 5
) {
    /**
     * Computed font size from preset
     */
    val fontSize: Int
        get() = fontSizePreset.fontSize

    /**
     * Computed PiP font size from preset
     */
    val pipFontSize: Int
        get() = pipFontSizePreset.pipFontSize

    /**
     * Get timer duration in seconds
     */
    val timerDurationSeconds: Int
        get() = timerMinutes * 60 + timerSeconds

    companion object {
        val DEFAULT = TeleprompterSettings()

        /**
         * Words per minute range
         */
        val WPM_RANGE = 50..300

        /**
         * Scroll speed range (multiplier)
         */
        val SCROLL_SPEED_RANGE = 0.5..3.0

        /**
         * Lines per minute range
         */
        val LPM_RANGE = 5..30
    }
}

/**
 * Information about a single word for highlighting
 */
data class WordInfo(
    val text: String,
    val startIndex: Int,
    val endIndex: Int,
    val isNote: Boolean
)

/**
 * Range of a [note] marker in the text
 */
data class NoteRange(
    val fullStartIndex: Int,
    val fullEndIndex: Int,
    val contentStartIndex: Int,
    val contentEndIndex: Int,
    val content: String
)

/**
 * Represents the teleprompter content
 * Text is displayed as a continuous flow with word-by-word highlighting
 */
data class TeleprompterContent(
    val fullText: String,
    val words: List<WordInfo>,
    val noteRanges: List<NoteRange>
)

/**
 * Saved note model
 */
data class SavedNote(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val content: String,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)
