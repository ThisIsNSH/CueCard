import Foundation
import SwiftUI

/// Theme preference for the app
enum ThemePreference: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Font size presets for teleprompter
enum FontSizePreset: String, Codable, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var fontSize: Int {
        switch self {
        case .small: return 20
        case .medium: return 28
        case .large: return 40
        }
    }

    var pipFontSize: Int {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 22
        }
    }
}

/// Overlay dimension ratio presets
enum OverlayAspectRatio: String, Codable, CaseIterable {
    case ratio16x9 = "16:9"
    case ratio4x3 = "4:3"
    case ratio1x1 = "1:1"

    var ratio: CGFloat {
        switch self {
        case .ratio16x9:
            return 16.0 / 9.0
        case .ratio4x3:
            return 4.0 / 3.0
        case .ratio1x1:
            return 1.0
        }
    }
}

/// Settings for the teleprompter
struct TeleprompterSettings: Codable, Equatable {
    var fontSizePreset: FontSizePreset
    var pipFontSizePreset: FontSizePreset
    var overlayAspectRatio: OverlayAspectRatio
    var scrollSpeed: Double
    var wordsPerMinute: Int
    var linesPerMinute: Int
    var timerMinutes: Int
    var timerSeconds: Int
    var autoScroll: Bool
    var themePreference: ThemePreference
    var countdownSeconds: Int

    /// Computed font size from preset
    var fontSize: Int {
        fontSizePreset.fontSize
    }

    /// Computed PiP font size from preset
    var pipFontSize: Int {
        pipFontSizePreset.pipFontSize
    }

    static let `default` = TeleprompterSettings(
        fontSizePreset: .medium,
        pipFontSizePreset: .medium,
        overlayAspectRatio: .ratio16x9,
        scrollSpeed: 1.0,
        wordsPerMinute: 150,
        linesPerMinute: 10,
        timerMinutes: 1,
        timerSeconds: 0,
        autoScroll: true,
        themePreference: .system,
        countdownSeconds: 5
    )

    /// Scroll speed range (multiplier)
    static let scrollSpeedRange = 0.5...3.0

    /// Words per minute range
    static let wpmRange = 50...300

    /// Lines per minute range
    static let lpmRange = 5...30

    /// Get timer duration in seconds
    var timerDurationSeconds: Int {
        timerMinutes * 60 + timerSeconds
    }

    enum CodingKeys: String, CodingKey {
        case fontSizePreset
        case pipFontSizePreset
        case overlayAspectRatio
        case scrollSpeed
        case wordsPerMinute
        case linesPerMinute
        case timerMinutes
        case timerSeconds
        case autoScroll
        case themePreference
        case countdownSeconds
    }

    init(
        fontSizePreset: FontSizePreset,
        pipFontSizePreset: FontSizePreset,
        overlayAspectRatio: OverlayAspectRatio,
        scrollSpeed: Double,
        wordsPerMinute: Int,
        linesPerMinute: Int,
        timerMinutes: Int,
        timerSeconds: Int,
        autoScroll: Bool,
        themePreference: ThemePreference,
        countdownSeconds: Int
    ) {
        self.fontSizePreset = fontSizePreset
        self.pipFontSizePreset = pipFontSizePreset
        self.overlayAspectRatio = overlayAspectRatio
        self.scrollSpeed = scrollSpeed
        self.wordsPerMinute = wordsPerMinute
        self.linesPerMinute = linesPerMinute
        self.timerMinutes = timerMinutes
        self.timerSeconds = timerSeconds
        self.autoScroll = autoScroll
        self.themePreference = themePreference
        self.countdownSeconds = countdownSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontSizePreset = try container.decode(FontSizePreset.self, forKey: .fontSizePreset)
        pipFontSizePreset = try container.decode(FontSizePreset.self, forKey: .pipFontSizePreset)
        overlayAspectRatio = try container.decodeIfPresent(OverlayAspectRatio.self, forKey: .overlayAspectRatio) ?? .ratio16x9
        scrollSpeed = try container.decode(Double.self, forKey: .scrollSpeed)
        wordsPerMinute = try container.decode(Int.self, forKey: .wordsPerMinute)
        linesPerMinute = try container.decode(Int.self, forKey: .linesPerMinute)
        timerMinutes = try container.decode(Int.self, forKey: .timerMinutes)
        timerSeconds = try container.decode(Int.self, forKey: .timerSeconds)
        autoScroll = try container.decode(Bool.self, forKey: .autoScroll)
        themePreference = try container.decode(ThemePreference.self, forKey: .themePreference)
        countdownSeconds = try container.decodeIfPresent(Int.self, forKey: .countdownSeconds) ?? 5
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fontSizePreset, forKey: .fontSizePreset)
        try container.encode(pipFontSizePreset, forKey: .pipFontSizePreset)
        try container.encode(overlayAspectRatio, forKey: .overlayAspectRatio)
        try container.encode(scrollSpeed, forKey: .scrollSpeed)
        try container.encode(wordsPerMinute, forKey: .wordsPerMinute)
        try container.encode(linesPerMinute, forKey: .linesPerMinute)
        try container.encode(timerMinutes, forKey: .timerMinutes)
        try container.encode(timerSeconds, forKey: .timerSeconds)
        try container.encode(autoScroll, forKey: .autoScroll)
        try container.encode(themePreference, forKey: .themePreference)
        try container.encode(countdownSeconds, forKey: .countdownSeconds)
    }
}

/// Service for persisting user settings
@MainActor
class SettingsService: ObservableObject {
    static let shared = SettingsService()

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "cuecard_settings"
    private let notesKey = "cuecard_notes"

    @Published var settings: TeleprompterSettings {
        didSet {
            saveSettings()
        }
    }

    @Published var notes: String {
        didSet {
            saveNotes()
        }
    }

    private init() {
        // Load settings from UserDefaults
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(TeleprompterSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }

        // Load notes from UserDefaults
        self.notes = userDefaults.string(forKey: notesKey) ?? ""
    }

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }

    private func saveNotes() {
        userDefaults.set(notes, forKey: notesKey)
    }

    /// Reset settings to defaults
    func resetSettings() {
        settings = .default
    }

    /// Clear all stored data
    func clearAllData() {
        settings = .default
        notes = ""
        userDefaults.removeObject(forKey: settingsKey)
        userDefaults.removeObject(forKey: notesKey)
    }
}
