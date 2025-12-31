import SwiftUI
import FirebaseAnalytics

struct HomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var settingsService: SettingsService
    @State private var showingSettings = false
    @State private var showingTeleprompter = false
    @FocusState private var isTextEditorFocused: Bool

    private var hasNotes: Bool {
        !settingsService.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Notes editor
                NotesEditorView(
                    text: $settingsService.notes,
                    isFocused: $isTextEditorFocused
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom action bar
                VStack(spacing: 12) {
                    Divider()

                    HStack(spacing: 16) {
                        // Tips button
                        Button(action: {
                            insertSampleNotes()
                        }) {
                            Label("Example", systemImage: "lightbulb")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)

                        Spacer()

                        // Start teleprompter button
                        Button(action: {
                            isTextEditorFocused = false
                            showingTeleprompter = true
                        }) {
                            Label("Start", systemImage: "play.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!hasNotes)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemBackground))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("CueCard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isTextEditorFocused = false
                        }
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

    private func insertSampleNotes() {
        settingsService.notes = """
        Welcome everyone!

        [time 00:30]
        I'm excited to be here today to talk about our new product launch.
        [note smile and pause]

        [time 01:00]
        Let me walk you through the key features that make this release special.

        First, we've completely redesigned the user interface.
        Second, performance improvements of up to 50%.
        [note emphasize this point]

        [time 00:45]
        In conclusion, this is our most ambitious update yet.

        Thank you for your time!
        [note pause for questions]
        """
    }
}

/// Notes editor with syntax highlighting for [time] and [note] tags
struct NotesEditorView: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text("Paste your notes here...\n\nUse [time mm:ss] for timer checkpoints\nUse [note text] for delivery cues")
                    .foregroundStyle(.tertiary)
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
                .font(.body)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthenticationService.shared)
        .environmentObject(SettingsService.shared)
}
