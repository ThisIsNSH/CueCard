import SwiftUI
import FirebaseAnalytics

struct HomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var settingsService: SettingsService
    @Environment(\.colorScheme) var colorScheme
    @State private var showingSettings = false
    @State private var showingTeleprompter = false
    @State private var showingTimerPicker = false
    @State private var showingSavedNotes = false
    @State private var showingSaveDialog = false
    @State private var saveNoteTitle = ""
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
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showingSavedNotes = true }) {
                        Image(systemName: "folder")
                            .font(.title3)
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Menu {
                            if settingsService.currentNoteId != nil && settingsService.hasUnsavedChanges {
                                Button(action: {
                                    settingsService.saveChangesToCurrentNote()
                                }) {
                                    Label("Save", systemImage: "square.and.arrow.down")
                                }
                            }

                            Button(action: {
                                saveNoteTitle = ""
                                showingSaveDialog = true
                            }) {
                                Label("Save as New", systemImage: "doc.badge.plus")
                            }
                            .disabled(!hasNotes)

                            Divider()

                            Button(action: {
                                settingsService.createNewNote()
                            }) {
                                Label("New Note", systemImage: "square.and.pencil")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        }

                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.title3)
                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingSavedNotes) {
                SavedNotesView()
            }
            .alert("Save Note", isPresented: $showingSaveDialog) {
                TextField("Note title", text: $saveNoteTitle)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    let title = saveNoteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty {
                        settingsService.saveCurrentNote(title: title)
                    }
                }
            } message: {
                Text("Enter a title for your note")
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

/// View for displaying and managing saved notes
struct SavedNotesView: View {
    @EnvironmentObject var settingsService: SettingsService
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var noteToRename: SavedNote?
    @State private var renameTitle = ""

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Group {
                if settingsService.savedNotes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 48))
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                        Text("No Saved Notes")
                            .font(.headline)
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                        Text("Save your notes to access them later")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.background(for: colorScheme))
                } else {
                    List {
                        ForEach(settingsService.savedNotes.sorted { $0.updatedAt > $1.updatedAt }) { note in
                            Button(action: {
                                settingsService.loadNote(note)
                                dismiss()
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title)
                                        .font(.headline)
                                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                                    Text(note.content.prefix(100).replacingOccurrences(of: "\n", with: " "))
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                                        .lineLimit(2)

                                    Text(dateFormatter.string(from: note.updatedAt))
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textSecondary(for: colorScheme).opacity(0.7))
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    settingsService.deleteNote(id: note.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    renameTitle = note.title
                                    noteToRename = note
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Saved Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Rename Note", isPresented: Binding(
                get: { noteToRename != nil },
                set: { if !$0 { noteToRename = nil } }
            )) {
                TextField("Note title", text: $renameTitle)
                Button("Cancel", role: .cancel) {
                    noteToRename = nil
                }
                Button("Rename") {
                    if let note = noteToRename {
                        let title = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !title.isEmpty {
                            settingsService.updateNote(id: note.id, title: title)
                        }
                    }
                    noteToRename = nil
                }
            } message: {
                Text("Enter a new title for your note")
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthenticationService.shared)
        .environmentObject(SettingsService.shared)
}

#Preview("Saved Notes") {
    SavedNotesView()
        .environmentObject(SettingsService.shared)
}
