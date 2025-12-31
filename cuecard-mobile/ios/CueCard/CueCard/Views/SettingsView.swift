import SwiftUI
import FirebaseAnalytics

struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var settingsService: SettingsService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                // User info section
                if let user = authService.user {
                    Section {
                        HStack(spacing: 16) {
                            AsyncImage(url: user.photoURL) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName ?? "User")
                                    .font(.headline)

                                Text(user.email ?? "")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Teleprompter settings
                Section("Teleprompter") {
                    // Font Size
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Font Size")
                            Spacer()
                            Text("\(settingsService.settings.fontSize)px")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(
                            value: Binding(
                                get: { Double(settingsService.settings.fontSize) },
                                set: { settingsService.settings.fontSize = Int($0) }
                            ),
                            in: Double(TeleprompterSettings.fontSizeRange.lowerBound)...Double(TeleprompterSettings.fontSizeRange.upperBound),
                            step: 1
                        )
                    }
                    .padding(.vertical, 4)

                    // Scroll Speed
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Scroll Speed")
                            Spacer()
                            Text(String(format: "%.1fx", settingsService.settings.scrollSpeed))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(
                            value: $settingsService.settings.scrollSpeed,
                            in: TeleprompterSettings.scrollSpeedRange,
                            step: 0.1
                        )
                    }
                    .padding(.vertical, 4)

                    // Opacity
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Opacity")
                            Spacer()
                            Text("\(settingsService.settings.opacity)%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(
                            value: Binding(
                                get: { Double(settingsService.settings.opacity) },
                                set: { settingsService.settings.opacity = Int($0) }
                            ),
                            in: Double(TeleprompterSettings.opacityRange.lowerBound)...Double(TeleprompterSettings.opacityRange.upperBound),
                            step: 1
                        )
                    }
                    .padding(.vertical, 4)
                }

                // Reset settings
                Section {
                    Button("Reset to Defaults") {
                        settingsService.resetSettings()
                    }
                }

                // Sign out section
                Section {
                    Button(role: .destructive) {
                        authService.signOut()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "settings"
            ])
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService.shared)
        .environmentObject(SettingsService.shared)
}
