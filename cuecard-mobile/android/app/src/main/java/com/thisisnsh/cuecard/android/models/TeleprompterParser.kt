package com.thisisnsh.cuecard.android.models

import java.util.regex.Pattern
import kotlin.math.abs
import kotlin.math.min

/**
 * Parser for teleprompter notes with [note content] tags
 */
object TeleprompterParser {

    private val NOTE_PATTERN: Pattern = Pattern.compile("\\[note\\s+([^\\]]+)\\]")

    data class DisplayTextResult(
        val text: String,
        val noteRanges: List<IntRange>,
        val emptyLineIndices: List<Int> = emptyList()
    )

    /**
     * Build display text with [note] tags replaced by their content.
     * Returns the display text, note ranges, and empty line indices.
     * Empty lines get a space character that can be styled with smaller font.
     */
    fun buildDisplayText(text: String): DisplayTextResult {
        // Step 1: Insert space before each empty line (consecutive newlines)
        val step1Builder = StringBuilder()
        val rawEmptyLineIndices = mutableListOf<Int>()
        var i = 0
        while (i < text.length) {
            if (text[i] == '\n') {
                step1Builder.append('\n')
                i++
                // For each following \n, insert a space (empty line marker)
                while (i < text.length && text[i] == '\n') {
                    rawEmptyLineIndices.add(step1Builder.length)
                    step1Builder.append(' ')
                    step1Builder.append('\n')
                    i++
                }
            } else {
                step1Builder.append(text[i])
                i++
            }
        }
        val step1Text = step1Builder.toString()

        // Step 2: Process [note] tags on the transformed text
        val matcher = NOTE_PATTERN.matcher(step1Text)
        val step2Builder = StringBuilder()
        val noteRanges = mutableListOf<IntRange>()
        val replacements = mutableListOf<Triple<Int, Int, Int>>() // (matchEnd, matchLen, contentLen)
        var lastIndex = 0

        while (matcher.find()) {
            step2Builder.append(step1Text.substring(lastIndex, matcher.start()))
            val content = matcher.group(1) ?: ""
            val start = step2Builder.length
            step2Builder.append(content)
            val end = step2Builder.length
            if (start < end) {
                noteRanges.add(start until end)
            }
            replacements.add(Triple(matcher.end(), matcher.group().length, content.length))
            lastIndex = matcher.end()
        }
        step2Builder.append(step1Text.substring(lastIndex))

        // Step 3: Adjust emptyLineIndices for [note] replacements
        val emptyLineIndices = rawEmptyLineIndices.map { rawIdx ->
            var adjustment = 0
            for ((matchEnd, matchLen, contentLen) in replacements) {
                if (matchEnd <= rawIdx) {
                    adjustment += (contentLen - matchLen)
                }
            }
            rawIdx + adjustment
        }

        return DisplayTextResult(step2Builder.toString(), noteRanges, emptyLineIndices)
    }

    /**
     * Parse notes content for teleprompter display
     * Only supports [note content] tags for delivery cues
     */
    fun parseNotes(notes: String): TeleprompterContent {
        val cleanedNotes = cleanText(notes)
        val noteRanges = findNoteRanges(cleanedNotes)
        val displayResult = buildDisplayText(cleanedNotes)
        val words = extractWords(displayResult.text, displayResult.noteRanges)

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
    private fun extractWords(displayText: String, noteRanges: List<IntRange>): List<WordInfo> {
        val words = mutableListOf<WordInfo>()

        // Extract words from display text
        val wordPattern = Pattern.compile("\\S+")
        val matcher = wordPattern.matcher(displayText)

        while (matcher.find()) {
            val word = matcher.group()
            val wordStart = matcher.start()
            val wordEnd = matcher.end()
            val isNote = noteRanges.any { range ->
                range.contains(wordStart) && range.contains(wordEnd - 1)
            }

            words.add(
                WordInfo(
                    text = word,
                    startIndex = wordStart,
                    endIndex = wordEnd,
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
        return buildDisplayText(text).text
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
