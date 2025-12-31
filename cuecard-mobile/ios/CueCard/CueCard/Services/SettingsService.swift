import Foundation
import SwiftUI

/// Settings for the teleprompter
struct TeleprompterSettings: Codable, Equatable {
    var fontSize: Int
    var scrollSpeed: Double
    var opacity: Int

    static let `default` = TeleprompterSettings(
        fontSize: 24,
        scrollSpeed: 1.0,
        opacity: 100
    )

    /// Font size range
    static let fontSizeRange = 16...48

    /// Scroll speed range (multiplier)
    static let scrollSpeedRange = 0.5...3.0

    /// Opacity range (percentage)
    static let opacityRange = 30...100
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
