import Foundation

/// Represents the teleprompter content
/// Text is displayed as a continuous flow with word-by-word highlighting
struct TeleprompterContent {
    /// The full text content (with [note] tags for styling)
    let fullText: String
    /// All words for highlighting (excluding [note] tag syntax)
    let words: [WordInfo]
    /// Note markers for styling
    let noteRanges: [NoteRange]
}

/// Information about a single word for highlighting
struct WordInfo: Identifiable {
    let id = UUID()
    let text: String
    let range: Range<String.Index>
    let isNote: Bool
}

/// Range of a [note] marker in the text
struct NoteRange {
    let fullRange: Range<String.Index>
    let contentRange: Range<String.Index>
    let content: String
}

/// Parser for teleprompter notes with [note content] tags
enum TeleprompterParser {

    /// Parse notes content for teleprompter display
    /// Only supports [note content] tags for delivery cues
    static func parseNotes(_ notes: String) -> TeleprompterContent {
        let cleanedNotes = cleanText(notes)
        let noteRanges = findNoteRanges(cleanedNotes)
        let words = extractWords(from: cleanedNotes, noteRanges: noteRanges)

        return TeleprompterContent(
            fullText: cleanedNotes,
            words: words,
            noteRanges: noteRanges
        )
    }

    /// Clean text for display
    private static func cleanText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Find all [note content] markers in text
    static func findNoteRanges(_ text: String) -> [NoteRange] {
        let notePattern = try! NSRegularExpression(
            pattern: #"\[note\s+([^\]]+)\]"#,
            options: []
        )

        let nsText = text as NSString
        let matches = notePattern.matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        )

        return matches.compactMap { match in
            guard let fullRange = Range(match.range, in: text),
                  let contentRange = Range(match.range(at: 1), in: text) else {
                return nil
            }

            return NoteRange(
                fullRange: fullRange,
                contentRange: contentRange,
                content: String(text[contentRange])
            )
        }
    }

    /// Extract words from text, marking which ones are inside [note] tags
    private static func extractWords(from text: String, noteRanges: [NoteRange]) -> [WordInfo] {
        var words: [WordInfo] = []
        var displayText = text

        // Process note ranges in reverse to maintain indices
        for noteRange in noteRanges.reversed() {
            let content = String(text[noteRange.contentRange])
            displayText.replaceSubrange(noteRange.fullRange, with: content)
        }

        // Now extract words from the display text
        let wordPattern = try! NSRegularExpression(
            pattern: #"\S+"#,
            options: []
        )

        let nsDisplayText = displayText as NSString
        let matches = wordPattern.matches(
            in: displayText,
            options: [],
            range: NSRange(location: 0, length: nsDisplayText.length)
        )

        for match in matches {
            guard let range = Range(match.range, in: displayText) else { continue }
            let word = String(displayText[range])

            // Check if this word is part of a note (simplified check)
            let isNote = noteRanges.contains { noteRange in
                let noteContent = String(text[noteRange.contentRange])
                return noteContent.contains(word)
            }

            words.append(WordInfo(
                text: word,
                range: range,
                isNote: isNote
            ))
        }

        return words
    }

    /// Get display text with [note] tags replaced by just their content
    static func getDisplayText(_ text: String) -> String {
        let notePattern = try! NSRegularExpression(
            pattern: #"\[note\s+([^\]]+)\]"#,
            options: []
        )

        let nsText = text as NSString
        return notePattern.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length),
            withTemplate: "$1"
        )
    }

    /// Format time as mm:ss string
    static func formatTime(_ seconds: Int) -> String {
        let isNegative = seconds < 0
        let absSeconds = abs(seconds)
        let minutes = absSeconds / 60
        let secs = absSeconds % 60
        let formatted = String(format: "%02d:%02d", minutes, secs)
        return isNegative ? "-\(formatted)" : formatted
    }

    /// Calculate word index based on elapsed time and words per minute
    static func calculateCurrentWordIndex(
        elapsedTime: Double,
        totalWords: Int,
        wordsPerMinute: Double
    ) -> Int {
        let wordsPerSecond = wordsPerMinute / 60.0
        let wordIndex = Int(elapsedTime * wordsPerSecond)
        return min(wordIndex, totalWords - 1)
    }

    /// Calculate line index based on elapsed time and lines per minute
    static func calculateCurrentLineIndex(
        elapsedTime: Double,
        totalLines: Int,
        linesPerMinute: Double
    ) -> Int {
        let linesPerSecond = linesPerMinute / 60.0
        let lineIndex = Int(elapsedTime * linesPerSecond)
        return min(lineIndex, totalLines - 1)
    }
}
