import AVKit
import UIKit
import Combine

/// Manager for Picture-in-Picture teleprompter functionality
/// Uses AVPictureInPictureVideoCallViewController for camera-compatible PiP
@MainActor
class TeleprompterPiPManager: NSObject, ObservableObject {
    static let shared = TeleprompterPiPManager()

    // MARK: - Published Properties

    @Published var isPiPActive = false
    @Published var isPiPPossible = false
    @Published var isPlaying = false

    // MARK: - Content Properties

    private(set) var segments: [TeleprompterSegment] = []
    private(set) var settings: TeleprompterSettings = .default
    private(set) var currentSegmentIndex: Int = 0
    private(set) var scrollOffset: CGFloat = 0
    private(set) var elapsedTime: Int = 0

    // MARK: - PiP Components

    private var pipController: AVPictureInPictureController?
    private var pipViewController: AVPictureInPictureVideoCallViewController?
    private var teleprompterContentView: TeleprompterPiPContentView?
    private var pipContentView: TeleprompterPiPContentView?
    private var pipWindow: UIWindow?

    // MARK: - Timers

    private var displayLink: CADisplayLink?
    private var scrollTimer: Timer?

    // MARK: - Callbacks

    var onPiPClosed: (() -> Void)?
    var onPiPRestoreUI: (() -> Void)?

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Configure the PiP manager with content
    func configure(segments: [TeleprompterSegment], settings: TeleprompterSettings) {
        self.segments = segments
        self.settings = settings
        self.currentSegmentIndex = 0
        self.scrollOffset = 0
        self.elapsedTime = 0

        setupPiP()
    }

    /// Update current state from TeleprompterView
    func updateState(segmentIndex: Int, scrollOffset: CGFloat, elapsedTime: Int, isPlaying: Bool) {
        self.currentSegmentIndex = segmentIndex
        self.scrollOffset = scrollOffset
        self.elapsedTime = elapsedTime
        self.isPlaying = isPlaying
        updateContentView()
    }

    /// Start PiP mode
    func startPiP() {
        guard let pipController = pipController else {
            print("PiP controller not available")
            return
        }

        guard pipController.isPictureInPicturePossible else {
            print("PiP is not possible")
            return
        }

        pipController.startPictureInPicture()
    }

    /// Stop PiP mode
    func stopPiP() {
        pipController?.stopPictureInPicture()
    }

    /// Toggle play/pause
    func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            startScrollTimer()
        } else {
            stopScrollTimer()
        }
        updateContentView()
    }

    /// Cleanup resources
    func cleanup() {
        stopScrollTimer()
        stopDisplayLink()
        pipController?.stopPictureInPicture()
        pipController = nil
        pipViewController = nil
        teleprompterContentView?.removeFromSuperview()
        teleprompterContentView = nil
        pipContentView?.removeFromSuperview()
        pipContentView = nil
        pipWindow?.isHidden = true
        pipWindow = nil
        isPiPActive = false
    }

    // MARK: - PiP Setup

    private func setupPiP() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("PiP not supported on this device")
            isPiPPossible = false
            return
        }

        // Create a hidden window for PiP content
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("No window scene available")
            return
        }

        // Create the teleprompter content view
        let contentView = TeleprompterPiPContentView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        contentView.backgroundColor = .black
        self.teleprompterContentView = contentView

        // Create a host view controller (NOT the PiP VC itself)
        let hostVC = UIViewController()
        hostVC.view.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: hostVC.view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: hostVC.view.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: hostVC.view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: hostVC.view.trailingAnchor)
        ])

        // Create a hidden window to host the source view
        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(x: -1000, y: -1000, width: 400, height: 300)
        window.rootViewController = hostVC
        window.isHidden = false
        window.windowLevel = .normal - 1
        self.pipWindow = window

        // Create the PiP video call view controller (managed by PiP system, not us)
        let pipVC = AVPictureInPictureVideoCallViewController()
        pipVC.preferredContentSize = CGSize(width: 400, height: 300)

        // Add content to PiP VC's view
        let pipContent = TeleprompterPiPContentView(frame: .zero)
        pipContent.backgroundColor = .black
        pipVC.view.addSubview(pipContent)
        pipContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pipContent.topAnchor.constraint(equalTo: pipVC.view.topAnchor),
            pipContent.bottomAnchor.constraint(equalTo: pipVC.view.bottomAnchor),
            pipContent.leadingAnchor.constraint(equalTo: pipVC.view.leadingAnchor),
            pipContent.trailingAnchor.constraint(equalTo: pipVC.view.trailingAnchor)
        ])
        self.pipContentView = pipContent
        self.pipViewController = pipVC

        // Create the PiP controller with video call content source
        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: contentView,
            contentViewController: pipVC
        )

        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        self.pipController = controller

        // Check if PiP is possible after setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isPiPPossible = controller.isPictureInPicturePossible
        }

        // Start rendering
        startDisplayLink()
        updateContentView()
    }

    // MARK: - Content Rendering

    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateDisplay))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30)
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateDisplay() {
        updateContentView()
    }

    private func updateContentView() {
        guard currentSegmentIndex < segments.count else { return }

        let segment = segments[currentSegmentIndex]
        let fontSize = CGFloat(settings.fontSize) * 0.5
        let timerText = segment.durationSeconds.map { duration in
            let remaining = max(0, duration - (elapsedTime - segment.startTimeSeconds))
            return TeleprompterParser.formatTime(remaining)
        }

        // Update both content views (source view and PiP view)
        teleprompterContentView?.update(
            text: segment.text,
            fontSize: fontSize,
            isPlaying: isPlaying,
            timerText: timerText,
            scrollOffset: scrollOffset
        )

        pipContentView?.update(
            text: segment.text,
            fontSize: fontSize,
            isPlaying: isPlaying,
            timerText: timerText,
            scrollOffset: scrollOffset
        )
    }

    // MARK: - Scroll Timer

    private func startScrollTimer() {
        stopScrollTimer()
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.elapsedTime += 1
                self.updateCurrentSegment()
                self.scrollOffset += CGFloat(self.settings.scrollSpeed) * 15
                self.updateContentView()
            }
        }
    }

    private func stopScrollTimer() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    private func updateCurrentSegment() {
        for (index, segment) in segments.enumerated() {
            if elapsedTime >= segment.startTimeSeconds {
                if let duration = segment.durationSeconds {
                    if elapsedTime < segment.startTimeSeconds + duration {
                        if currentSegmentIndex != index {
                            currentSegmentIndex = index
                            scrollOffset = 0
                        }
                        break
                    }
                } else {
                    if currentSegmentIndex != index {
                        currentSegmentIndex = index
                        scrollOffset = 0
                    }
                }
            }
        }

        // Auto-advance
        if let current = segments[safe: currentSegmentIndex],
           let duration = current.durationSeconds,
           elapsedTime >= current.startTimeSeconds + duration {
            if currentSegmentIndex < segments.count - 1 {
                currentSegmentIndex += 1
                scrollOffset = 0
            }
        }
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension TeleprompterPiPManager: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isPiPActive = true
            if isPlaying {
                startScrollTimer()
            }
        }
    }

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isPiPActive = true
        }
    }

    nonisolated func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            stopScrollTimer()
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isPiPActive = false
            onPiPClosed?()
        }
    }

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor in
            onPiPRestoreUI?()
            completionHandler(true)
        }
    }
}

// MARK: - Teleprompter PiP Content View

private class TeleprompterPiPContentView: UIView {
    private let textLabel = UILabel()
    private let timerLabel = UILabel()
    private let playPauseIndicator = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .black

        // Text label
        textLabel.numberOfLines = 0
        textLabel.textColor = .white
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textLabel)

        // Timer label
        timerLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        timerLabel.textColor = .white
        timerLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        timerLabel.textAlignment = .center
        timerLabel.layer.cornerRadius = 4
        timerLabel.layer.masksToBounds = true
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(timerLabel)

        // Play/Pause indicator
        playPauseIndicator.tintColor = .white.withAlphaComponent(0.8)
        playPauseIndicator.contentMode = .scaleAspectFit
        playPauseIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(playPauseIndicator)

        NSLayoutConstraint.activate([
            // Timer at top left
            timerLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            timerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            timerLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            timerLabel.heightAnchor.constraint(equalToConstant: 24),

            // Play/Pause at top right
            playPauseIndicator.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            playPauseIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            playPauseIndicator.widthAnchor.constraint(equalToConstant: 20),
            playPauseIndicator.heightAnchor.constraint(equalToConstant: 20),

            // Text in main area
            textLabel.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 8),
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    func update(text: String, fontSize: CGFloat, isPlaying: Bool, timerText: String?, scrollOffset: CGFloat) {
        // Update text with note highlighting
        textLabel.attributedText = createAttributedText(text, fontSize: fontSize)

        // Update timer
        if let timer = timerText {
            timerLabel.text = " \(timer) "
            timerLabel.isHidden = false
        } else {
            timerLabel.isHidden = true
        }

        // Update play/pause indicator
        let imageName = isPlaying ? "pause.fill" : "play.fill"
        playPauseIndicator.image = UIImage(systemName: imageName)

        // Apply scroll offset as content offset transform
        let maxOffset = max(0, textLabel.intrinsicContentSize.height - bounds.height + 60)
        let clampedOffset = min(scrollOffset, maxOffset)
        textLabel.transform = CGAffineTransform(translationX: 0, y: -clampedOffset)
    }

    private func createAttributedText(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let notePattern = try! NSRegularExpression(pattern: #"\[note\s+([^\]]+)\]"#, options: [])

        let nsText = text as NSString
        var lastEnd = 0

        let matches = notePattern.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            // Add text before the note
            if match.range.location > lastEnd {
                let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                let beforeText = nsText.substring(with: beforeRange)
                result.append(NSAttributedString(
                    string: beforeText,
                    attributes: [.font: font, .foregroundColor: UIColor.white]
                ))
            }

            // Add the note content (highlighted in pink)
            let contentRange = match.range(at: 1)
            let noteContent = nsText.substring(with: contentRange)
            result.append(NSAttributedString(
                string: noteContent,
                attributes: [
                    .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                    .foregroundColor: UIColor.systemPink
                ]
            ))

            lastEnd = match.range.location + match.range.length
        }

        // Add remaining text
        if lastEnd < nsText.length {
            let remainingRange = NSRange(location: lastEnd, length: nsText.length - lastEnd)
            let remainingText = nsText.substring(with: remainingRange)
            result.append(NSAttributedString(
                string: remainingText,
                attributes: [.font: font, .foregroundColor: UIColor.white]
            ))
        }

        // Add paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = fontSize * 0.3
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))

        return result
    }
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
