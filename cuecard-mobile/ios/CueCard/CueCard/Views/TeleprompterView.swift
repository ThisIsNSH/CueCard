import SwiftUI
import FirebaseAnalytics
import Combine

struct TeleprompterView: View {
    let content: TeleprompterContent
    let settings: TeleprompterSettings

    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var pipManager = TeleprompterPiPManager.shared

    @State private var isPlaying = false
    @State private var scrollOffset: CGFloat = 0
    @State private var elapsedTime: Int = 0
    @State private var currentSegmentIndex: Int = 0
    @State private var timer: Timer?
    @State private var contentHeight: CGFloat = 0
    @State private var viewHeight: CGFloat = 0
    @State private var showControls = true
    @State private var controlsTimer: Timer?

    private var currentSegment: TeleprompterSegment? {
        guard currentSegmentIndex < content.segments.count else { return nil }
        return content.segments[currentSegmentIndex]
    }

    private var timeDisplay: String {
        if let segment = currentSegment, let duration = segment.durationSeconds {
            let remaining = max(0, duration - (elapsedTime - segment.startTimeSeconds))
            return TeleprompterParser.formatTime(remaining)
        }
        return TeleprompterParser.formatTime(elapsedTime)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()

                // Teleprompter content
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            // Top padding for starting position
                            Color.clear
                                .frame(height: geometry.size.height * 0.4)
                                .id("top")

                            // Content segments
                            ForEach(Array(content.segments.enumerated()), id: \.element.id) { index, segment in
                                SegmentView(
                                    segment: segment,
                                    fontSize: CGFloat(settings.fontSize),
                                    isCurrentSegment: index == currentSegmentIndex
                                )
                                .id(segment.id)
                            }

                            // Bottom padding
                            Color.clear
                                .frame(height: geometry.size.height * 0.6)
                        }
                        .padding(.horizontal, 24)
                        .background(
                            GeometryReader { contentGeometry in
                                Color.clear.onAppear {
                                    contentHeight = contentGeometry.size.height
                                }
                            }
                        )
                    }
                    .onChange(of: currentSegmentIndex) { _, newIndex in
                        if newIndex < content.segments.count {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                scrollProxy.scrollTo(content.segments[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
                .opacity(Double(settings.opacity) / 100.0)

                // Tap to show/hide controls
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showControls.toggle()
                        }
                        resetControlsTimer()
                    }

                // Timer overlay (top left) - always visible
                VStack {
                    HStack {
                        if content.hasTiming {
                            Text(timeDisplay)
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Spacer()

                        // PiP indicator
                        if pipManager.isPiPPossible {
                            Button(action: { startPiP() }) {
                                Image(systemName: "pip.enter")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding()
                    Spacer()
                }

                // Controls overlay
                if showControls {
                    VStack {
                        Spacer()

                        HStack(spacing: 32) {
                            // Close button
                            Button(action: { stopAndDismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.white.opacity(0.8))
                            }

                            // Play/Pause button
                            Button(action: { togglePlayPause() }) {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(.white)
                            }

                            // Restart button
                            Button(action: { restart() }) {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(.bottom, 48)
                    }
                    .transition(.opacity)
                }

                // Swipe up hint
                if !isPlaying && showControls {
                    VStack {
                        Spacer()
                        Text("Swipe up for Picture-in-Picture")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.bottom, 120)
                    }
                }
            }
            .onAppear {
                viewHeight = geometry.size.height
                setupPiP()
                Analytics.logEvent("teleprompter_started", parameters: [
                    "segment_count": content.segments.count,
                    "has_timing": content.hasTiming
                ])
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .onChange(of: pipManager.isPiPActive) { _, isPiPActive in
            if isPiPActive {
                // PiP started, pause our timer (PiP manager handles its own)
                stopTimer()
            }
        }
        .onDisappear {
            stopTimer()
            stopControlsTimer()
        }
    }

    // MARK: - PiP Setup

    private func setupPiP() {
        // Configure PiP manager
        pipManager.configure(segments: content.segments, settings: settings)

        // Handle PiP closed
        pipManager.onPiPClosed = {
            // PiP was closed, resume our state from PiP manager
            currentSegmentIndex = pipManager.currentSegmentIndex
            elapsedTime = pipManager.elapsedTime
            isPlaying = pipManager.isPlaying
            if isPlaying {
                startTimer()
            }
        }

        // Handle restore UI (user tapped to return to app)
        pipManager.onPiPRestoreUI = {
            // Sync state from PiP
            currentSegmentIndex = pipManager.currentSegmentIndex
            elapsedTime = pipManager.elapsedTime
            isPlaying = pipManager.isPlaying
            if isPlaying {
                startTimer()
            }
        }
    }

    private func startPiP() {
        // Sync current state to PiP manager
        pipManager.updateState(
            segmentIndex: currentSegmentIndex,
            scrollOffset: scrollOffset,
            elapsedTime: elapsedTime,
            isPlaying: isPlaying
        )

        // Start PiP
        pipManager.startPiP()

        Analytics.logEvent("teleprompter_pip_started", parameters: nil)
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        if oldPhase == .active && newPhase == .inactive {
            // App is going to background - start PiP if playing
            if isPlaying && pipManager.isPiPPossible && !pipManager.isPiPActive {
                startPiP()
            }
        } else if newPhase == .active && pipManager.isPiPActive {
            // Coming back to foreground while PiP is active
            // PiP will handle the transition via onPiPRestoreUI
        }
    }

    // MARK: - Controls

    private func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
        resetControlsTimer()
    }

    private func play() {
        isPlaying = true
        startTimer()
        pipManager.updateState(
            segmentIndex: currentSegmentIndex,
            scrollOffset: scrollOffset,
            elapsedTime: elapsedTime,
            isPlaying: true
        )
        Analytics.logEvent("teleprompter_play", parameters: nil)
        resetControlsTimer()
    }

    private func pause() {
        isPlaying = false
        stopTimer()
        pipManager.updateState(
            segmentIndex: currentSegmentIndex,
            scrollOffset: scrollOffset,
            elapsedTime: elapsedTime,
            isPlaying: false
        )
        Analytics.logEvent("teleprompter_pause", parameters: nil)
    }

    private func restart() {
        stopTimer()
        elapsedTime = 0
        currentSegmentIndex = 0
        scrollOffset = 0
        isPlaying = false
        pipManager.updateState(
            segmentIndex: 0,
            scrollOffset: 0,
            elapsedTime: 0,
            isPlaying: false
        )
        Analytics.logEvent("teleprompter_restart", parameters: nil)
    }

    private func stopAndDismiss() {
        stopTimer()
        pipManager.cleanup()
        Analytics.logEvent("teleprompter_closed", parameters: [
            "elapsed_time": elapsedTime
        ])
        dismiss()
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                elapsedTime += 1
                updateCurrentSegment()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateCurrentSegment() {
        // Find the segment that contains the current elapsed time
        for (index, segment) in content.segments.enumerated() {
            if elapsedTime >= segment.startTimeSeconds {
                if let duration = segment.durationSeconds {
                    if elapsedTime < segment.startTimeSeconds + duration {
                        if currentSegmentIndex != index {
                            currentSegmentIndex = index
                        }
                        break
                    }
                } else {
                    // No timing, stay on this segment
                    if currentSegmentIndex != index {
                        currentSegmentIndex = index
                    }
                }
            }
        }

        // Auto-advance to next segment when duration expires
        if let current = currentSegment,
           let duration = current.durationSeconds,
           elapsedTime >= current.startTimeSeconds + duration {
            if currentSegmentIndex < content.segments.count - 1 {
                currentSegmentIndex += 1
            }
        }

        // Update PiP manager state
        pipManager.updateState(
            segmentIndex: currentSegmentIndex,
            scrollOffset: scrollOffset,
            elapsedTime: elapsedTime,
            isPlaying: isPlaying
        )
    }

    // MARK: - Controls Timer

    private func resetControlsTimer() {
        stopControlsTimer()
        if isPlaying {
            controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls = false
                    }
                }
            }
        }
    }

    private func stopControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = nil
    }
}

/// View for a single teleprompter segment
struct SegmentView: View {
    let segment: TeleprompterSegment
    let fontSize: CGFloat
    let isCurrentSegment: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timing badge
            if let duration = segment.durationSeconds {
                Text(TeleprompterParser.formatTime(duration))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Segment text with note highlighting
            FormattedTextView(text: segment.text, fontSize: fontSize)
        }
        .opacity(isCurrentSegment ? 1.0 : 0.4)
        .animation(.easeInOut(duration: 0.3), value: isCurrentSegment)
    }
}

/// View that formats text with [note] highlighting
struct FormattedTextView: View {
    let text: String
    let fontSize: CGFloat

    var body: some View {
        let attributed = formatText(text)

        Text(attributed)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(.white)
            .lineSpacing(fontSize * 0.4)
    }

    private func formatText(_ text: String) -> AttributedString {
        var result = AttributedString(text)

        // Find and style [note content] tags
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

        // Apply pink styling to note content
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: text),
                  let contentRange = Range(match.range(at: 1), in: text) else {
                continue
            }

            // Find the range in AttributedString
            if let attrRange = result.range(of: String(text[fullRange])) {
                // Replace with just the content, styled pink
                var replacement = AttributedString(String(text[contentRange]))
                replacement.foregroundColor = .pink
                replacement.font = .system(size: fontSize, weight: .bold)
                result.replaceSubrange(attrRange, with: replacement)
            }
        }

        return result
    }
}

#Preview {
    TeleprompterView(
        content: TeleprompterParser.parseNotes("""
            Welcome everyone!

            [time 00:30]
            I'm excited to be here today.
            [note smile and pause]

            [time 01:00]
            Let me walk you through the key features.
            [note emphasize this point]

            Thank you!
            """),
        settings: .default
    )
}
