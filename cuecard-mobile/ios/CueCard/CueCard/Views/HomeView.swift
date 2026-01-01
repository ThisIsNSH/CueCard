import SwiftUI
import FirebaseAnalytics

struct HomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var settingsService: SettingsService
    @Environment(\.colorScheme) var colorScheme
    @State private var showingSettings = false
    @State private var showingTeleprompter = false
    @State private var showingTimerPicker = false
    @FocusState private var isTextEditorFocused: Bool

    private var hasNotes: Bool {
        !settingsService.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background - matches TeleprompterView
                AppColors.background(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Notes editor
                    NotesEditorView(
                        text: $settingsService.notes,
                        isFocused: $isTextEditorFocused,
                        colorScheme: colorScheme
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 12) {
                        if showingTimerPicker {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Timer")
                                        .font(.headline)
                                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                                    Spacer()

                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showingTimerPicker = false
                                        }
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                                            .padding(6)
                                            .background(
                                                Circle()
                                                    .fill(AppColors.background(for: colorScheme).opacity(0.85))
                                            )
                                    }
                                }

                                HStack(spacing: 12) {
                                    Text("Duration")
                                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                                    Spacer()

                                    Picker("Minutes", selection: $settingsService.settings.timerMinutes) {
                                        ForEach(0..<60) { minute in
                                            Text("\(minute)").tag(minute)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 60, height: 88)
                                    .clipped()

                                    Text(":")
                                        .font(.headline)
                                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                                    Picker("Seconds", selection: $settingsService.settings.timerSeconds) {
                                        ForEach(0..<60) { second in
                                            Text(String(format: "%02d", second)).tag(second)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 60, height: 88)
                                    .clipped()
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AppColors.background(for: colorScheme))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(AppColors.textSecondary(for: colorScheme).opacity(0.2))
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingTimerPicker.toggle()
                            }
                        }) {
                            Text(showingTimerPicker ? "Done" : "Set Timer")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .glassedEffect(in: Capsule())
                        }
                    }

                    Spacer(minLength: 12)

                    Button(action: {
                        isTextEditorFocused = false
                        showingTeleprompter = true
                    }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(colorScheme == .dark ? .black : .white)
                            .frame(width: 52, height: 52)
                            .background(
                                Circle()
                                    .fill(AppColors.green(for: colorScheme))
                            )
                            .glassedEffect(in: Circle())
                    }
                    .disabled(!hasNotes)
                    .opacity(hasNotes ? 1.0 : 0.6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .navigationTitle("CueCard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showingTeleprompter) {
                TeleprompterView(
                    content: TeleprompterParser.parseNotes(settingsService.notes),
                    settings: settingsService.settings
                )
            }
        }
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "home"
            ])
        }
    }
}

/// Notes editor with syntax highlighting for [note] tags
struct NotesEditorView: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let colorScheme: ColorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text("Paste your script here...\n\nUse [note text] for delivery cues\nSet timer duration below")
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme).opacity(0.6))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }

            // Text editor
            TextEditor(text: $text)
                .focused(isFocused)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthenticationService.shared)
        .environmentObject(SettingsService.shared)
}
