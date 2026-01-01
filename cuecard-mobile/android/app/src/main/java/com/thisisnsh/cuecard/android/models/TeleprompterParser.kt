package com.thisisnsh.cuecard.android.models

import java.util.regex.Pattern
import kotlin.math.abs
import kotlin.math.min

/**
 * Parser for teleprompter notes with [note content] tags
 */
object TeleprompterParser {

    private val NOTE_PATTERN: Pattern = Pattern.compile("\\[note\\s+([^\\]]+)\\]")

    /**
     * Parse notes content for teleprompter display
     * Only supports [note content] tags for delivery cues
     */
    fun parseNotes(notes: String): TeleprompterContent {
        val cleanedNotes = cleanText(notes)
        val noteRanges = findNoteRanges(cleanedNotes)
        val words = extractWords(cleanedNotes, noteRanges)

        return TeleprompterContent(
            fullText = cleanedNotes,
            words = words,
            noteRanges = noteRanges
        )
    }

    /**
     * Clean text for display
     */
    private fun cleanText(text: String): String {
        return text
            .replace("\r\n", "\n")
            .replace("\r", "\n")
            .trim()
    }

    /**
     * Find all [note content] markers in text
     */
    fun findNoteRanges(text: String): List<NoteRange> {
        val ranges = mutableListOf<NoteRange>()
        val matcher = NOTE_PATTERN.matcher(text)

        while (matcher.find()) {
            ranges.add(
                NoteRange(
                    fullStartIndex = matcher.start(),
                    fullEndIndex = matcher.end(),
                    contentStartIndex = matcher.start(1),
                    contentEndIndex = matcher.end(1),
                    content = matcher.group(1) ?: ""
                )
            )
        }

        return ranges
    }

    /**
     * Extract words from text, marking which ones are inside [note] tags
     */
    private fun extractWords(text: String, noteRanges: List<NoteRange>): List<WordInfo> {
        val words = mutableListOf<WordInfo>()

        // Build display text by replacing [note ...] with just the content
        var displayText = text
        var offset = 0

        for (noteRange in noteRanges) {
            val fullLength = noteRange.fullEndIndex - noteRange.fullStartIndex
            val contentLength = noteRange.content.length
            val startIdx = noteRange.fullStartIndex - offset
            val endIdx = noteRange.fullEndIndex - offset

            displayText = displayText.substring(0, startIdx) +
                    noteRange.content +
                    displayText.substring(endIdx)

            offset += fullLength - contentLength
        }

        // Extract words from display text
        val wordPattern = Pattern.compile("\\S+")
        val matcher = wordPattern.matcher(displayText)

        while (matcher.find()) {
            val word = matcher.group()
            val isNote = noteRanges.any { noteRange ->
                noteRange.content.contains(word)
            }

            words.add(
                WordInfo(
                    text = word,
                    startIndex = matcher.start(),
                    endIndex = matcher.end(),
                    isNote = isNote
                )
            )
        }

        return words
    }

    /**
     * Get display text with [note] tags replaced by just their content
     */
    fun getDisplayText(text: String): String {
        return NOTE_PATTERN.matcher(text).replaceAll("$1")
    }

    /**
     * Format time as mm:ss string
     */
    fun formatTime(seconds: Int): String {
        val isNegative = seconds < 0
        val absSeconds = abs(seconds)
        val minutes = absSeconds / 60
        val secs = absSeconds % 60
        val formatted = String.format("%02d:%02d", minutes, secs)
        return if (isNegative) "-$formatted" else formatted
    }

    /**
     * Calculate word index based on elapsed time and words per minute
     */
    fun calculateCurrentWordIndex(
        elapsedTime: Double,
        totalWords: Int,
        wordsPerMinute: Double
    ): Int {
        val wordsPerSecond = wordsPerMinute / 60.0
        val wordIndex = (elapsedTime * wordsPerSecond).toInt()
        return min(wordIndex, totalWords - 1)
    }

    /**
     * Calculate line index based on elapsed time and lines per minute
     */
    fun calculateCurrentLineIndex(
        elapsedTime: Double,
        totalLines: Int,
        linesPerMinute: Double
    ): Int {
        val linesPerSecond = linesPerMinute / 60.0
        val lineIndex = (elapsedTime * linesPerSecond).toInt()
        return min(lineIndex, totalLines - 1)
    }

    /**
     * Extract note content from a line containing [note ...]
     */
    fun extractNoteContent(line: String): String {
        val matcher = NOTE_PATTERN.matcher(line)
        return if (matcher.find()) {
            matcher.group(1) ?: line
        } else {
            line
        }
    }
}
