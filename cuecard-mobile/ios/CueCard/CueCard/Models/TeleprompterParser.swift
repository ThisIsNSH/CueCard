import Foundation

/// Represents a segment of the teleprompter content
/// Each segment is separated by [time mm:ss] tags
struct TeleprompterSegment: Identifiable {
    let id = UUID()
    /// The text content (with [note] tags preserved, [time] tags removed)
    let text: String
    /// Duration in seconds for this segment (nil = use default speed)
    let durationSeconds: Int?
    /// Cumulative start time in seconds from beginning
    let startTimeSeconds: Int
}

/// Parsed content ready for teleprompter display
struct TeleprompterContent {
    /// All segments parsed from the notes
    let segments: [TeleprompterSegment]
    /// Total duration if all segments have timing, nil otherwise
    let totalDurationSeconds: Int?
    /// Whether any segment has timing information
    let hasTiming: Bool
}

/// A note marker found in the text
struct NoteMarker {
    let content: String
    let range: Range<String.Index>
}

/// Parser for teleprompter notes with [time mm:ss] and [note content] tags
enum TeleprompterParser {

    /// Parse notes content into teleprompter segments
    ///
    /// # Format
    /// - `[time mm:ss]` - Defines timing for the following section
    /// - `[note content]` - Preserved for pink highlighting
    ///
    /// # Example
    /// ```
    /// Welcome!                <- No timer, uses default speed
    ///
    /// [time 00:30]            <- This section scrolls in 30 seconds
    /// This scrolls in 30 seconds.
    /// [note remember to smile]
    ///
    /// [time 01:00]            <- This section scrolls in 1 minute
    /// This scrolls in 1 minute.
    ///
    /// Conclusion.             <- Still part of 1-minute section
    /// ```
    static func parseNotes(_ notes: String) -> TeleprompterContent {
        let timePattern = try! NSRegularExpression(
            pattern: #"\[time\s+(\d{1,2}):(\d{2})\]"#,
            options: []
        )

        var segments: [TeleprompterSegment] = []
        var cumulativeTime: Int = 0
        var hasAnyTiming = false

        let nsNotes = notes as NSString
        let matches = timePattern.matches(
            in: notes,
            options: [],
            range: NSRange(location: 0, length: nsNotes.length)
        )

        var lastEnd = 0
        var pendingDuration: Int? = nil

        for match in matches {
            let fullMatchRange = match.range

            // Parse minutes and seconds
            let minutesRange = match.range(at: 1)
            let secondsRange = match.range(at: 2)

            let minutes = Int(nsNotes.substring(with: minutesRange)) ?? 0
            let seconds = Int(nsNotes.substring(with: secondsRange)) ?? 0
            let duration = minutes * 60 + seconds

            // Get text before this [time] tag
            let textBeforeRange = NSRange(location: lastEnd, length: fullMatchRange.location - lastEnd)
            let textBefore = nsNotes.substring(with: textBeforeRange)
            let cleanedText = cleanTextForDisplay(textBefore)

            if !cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(TeleprompterSegment(
                    text: cleanedText,
                    durationSeconds: pendingDuration,
                    startTimeSeconds: cumulativeTime
                ))

                if let d = pendingDuration {
                    cumulativeTime += d
                }
            }

            pendingDuration = duration
            hasAnyTiming = true
            lastEnd = fullMatchRange.location + fullMatchRange.length
        }

        // Handle remaining text after last [time] tag
        if lastEnd < nsNotes.length {
            let remainingRange = NSRange(location: lastEnd, length: nsNotes.length - lastEnd)
            let remainingText = nsNotes.substring(with: remainingRange)
            let cleanedRemaining = cleanTextForDisplay(remainingText)

            if !cleanedRemaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(TeleprompterSegment(
                    text: cleanedRemaining,
                    durationSeconds: pendingDuration,
                    startTimeSeconds: cumulativeTime
                ))

                if let d = pendingDuration {
                    cumulativeTime += d
                }
            }
        }

        // If no segments were created (no [time] tags), create one segment with all content
        if segments.isEmpty && !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            segments.append(TeleprompterSegment(
                text: cleanTextForDisplay(notes),
                durationSeconds: nil,
                startTimeSeconds: 0
            ))
        }

        // Calculate total duration (only if all segments have timing)
        let allHaveTiming = hasAnyTiming && segments.allSatisfy { $0.durationSeconds != nil }
        let totalDuration: Int? = allHaveTiming
            ? segments.compactMap { $0.durationSeconds }.reduce(0, +)
            : nil

        return TeleprompterContent(
            segments: segments,
            totalDurationSeconds: totalDuration,
            hasTiming: hasAnyTiming
        )
    }

    /// Clean text for display in teleprompter
    /// - Removes [time mm:ss] tags
    /// - Preserves [note content] tags (will be styled pink)
    /// - Normalizes whitespace
    private static func cleanTextForDisplay(_ text: String) -> String {
        let timePattern = try! NSRegularExpression(
            pattern: #"\[time\s+\d{1,2}:\d{2}\]"#,
            options: []
        )

        let nsText = text as NSString
        let cleaned = timePattern.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length),
            withTemplate: ""
        )

        return cleaned
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Find all [note content] markers in text
    static func findNoteMarkers(_ text: String) -> [NoteMarker] {
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
            guard let contentRange = Range(match.range(at: 1), in: text),
                  let fullRange = Range(match.range, in: text) else {
                return nil
            }

            return NoteMarker(
                content: String(text[contentRange]),
                range: fullRange
            )
        }
    }

    /// Calculate scroll speed for a segment
    ///
    /// - Parameters:
    ///   - segmentHeight: Height of the segment in points
    ///   - durationSeconds: Duration for the segment (nil = use default)
    ///   - defaultSpeed: Default speed in points per second
    /// - Returns: Scroll speed in points per second
    static func calculateScrollSpeed(
        segmentHeight: CGFloat,
        durationSeconds: Int?,
        defaultSpeed: CGFloat
    ) -> CGFloat {
        guard let duration = durationSeconds, duration > 0 else {
            return defaultSpeed
        }
        return segmentHeight / CGFloat(duration)
    }

    /// Format time as mm:ss string
    static func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
