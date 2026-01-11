package com.thisisnsh.cuecard.android.services

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.thisisnsh.cuecard.android.models.FontSizePreset
import com.thisisnsh.cuecard.android.models.OverlayAspectRatio
import com.thisisnsh.cuecard.android.models.SavedNote
import com.thisisnsh.cuecard.android.models.TeleprompterSettings
import com.thisisnsh.cuecard.android.models.ThemePreference
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "cuecard_settings")

/**
 * Service for persisting user settings using DataStore
 */
class SettingsService(private val context: Context) {

    companion object {
        val DEFAULT_NOTE_TEXT = """
Welcome everyone.

I'm excited to be here today to talk about CueCard.

[note smile and pause]

It keeps your speaker notes visible above all apps, so you can use your existing camera apps and still read your notes.

[note pause]

It has a timer so you know if you're being brief… or too passionate.

[note light chuckle]

And the pink highlights?

[note emphasize]

Those are your secret cues — reminders to smile, pause, or not panic.

[note pause]

Try it out. I think you'll love it.
""".trimIndent()
        // Preference keys
        private val FONT_SIZE_PRESET = stringPreferencesKey("font_size_preset")
        private val PIP_FONT_SIZE_PRESET = stringPreferencesKey("pip_font_size_preset")
        private val OVERLAY_ASPECT_RATIO = stringPreferencesKey("overlay_aspect_ratio")
        private val SCROLL_SPEED = doublePreferencesKey("scroll_speed")
        private val WORDS_PER_MINUTE = intPreferencesKey("words_per_minute")
        private val LINES_PER_MINUTE = intPreferencesKey("lines_per_minute")
        private val TIMER_MINUTES = intPreferencesKey("timer_minutes")
        private val TIMER_SECONDS = intPreferencesKey("timer_seconds")
        private val AUTO_SCROLL = booleanPreferencesKey("auto_scroll")
        private val THEME_PREFERENCE = stringPreferencesKey("theme_preference")
        private val COUNTDOWN_SECONDS = intPreferencesKey("countdown_seconds")
        private val NOTES = stringPreferencesKey("notes")
        private val SAVED_NOTES = stringPreferencesKey("saved_notes")
        private val CURRENT_NOTE_ID = stringPreferencesKey("current_note_id")

        @Volatile
        private var instance: SettingsService? = null

        fun getInstance(context: Context): SettingsService {
            return instance ?: synchronized(this) {
                instance ?: SettingsService(context.applicationContext).also { instance = it }
            }
        }
    }

    private val _settings = MutableStateFlow(TeleprompterSettings.DEFAULT)
    val settings: StateFlow<TeleprompterSettings> = _settings.asStateFlow()

    private val _notes = MutableStateFlow("")
    val notes: StateFlow<String> = _notes.asStateFlow()

    private val _savedNotes = MutableStateFlow<List<SavedNote>>(emptyList())
    val savedNotes: StateFlow<List<SavedNote>> = _savedNotes.asStateFlow()

    private val _currentNoteId = MutableStateFlow<String?>(null)
    val currentNoteId: StateFlow<String?> = _currentNoteId.asStateFlow()

    private var isLoadingNote = false

    private val json = Json { ignoreUnknownKeys = true }

    /**
     * Flow of settings from DataStore
     */
    val settingsFlow: Flow<TeleprompterSettings> = context.dataStore.data.map { prefs ->
        TeleprompterSettings(
            fontSizePreset = FontSizePreset.fromString(prefs[FONT_SIZE_PRESET] ?: FontSizePreset.MEDIUM.displayName),
            pipFontSizePreset = FontSizePreset.fromString(prefs[PIP_FONT_SIZE_PRESET] ?: FontSizePreset.MEDIUM.displayName),
            overlayAspectRatio = OverlayAspectRatio.fromString(prefs[OVERLAY_ASPECT_RATIO] ?: OverlayAspectRatio.RATIO_16X9.displayName),
            scrollSpeed = prefs[SCROLL_SPEED] ?: 1.0,
            wordsPerMinute = prefs[WORDS_PER_MINUTE] ?: 150,
            linesPerMinute = prefs[LINES_PER_MINUTE] ?: 10,
            timerMinutes = prefs[TIMER_MINUTES] ?: 1,
            timerSeconds = prefs[TIMER_SECONDS] ?: 0,
            autoScroll = true,
            themePreference = ThemePreference.fromString(prefs[THEME_PREFERENCE] ?: ThemePreference.SYSTEM.displayName),
            countdownSeconds = prefs[COUNTDOWN_SECONDS] ?: 5
        )
    }

    /**
     * Flow of notes from DataStore
     */
    val notesFlow: Flow<String> = context.dataStore.data.map { prefs ->
        prefs[NOTES] ?: ""
    }

    /**
     * Load settings from DataStore
     */
    suspend fun loadSettings() {
        _settings.value = settingsFlow.first()
        _notes.value = notesFlow.first()

        // Load saved notes
        context.dataStore.data.first().let { prefs ->
            prefs[SAVED_NOTES]?.let { jsonStr ->
                try {
                    _savedNotes.value = json.decodeFromString<List<SavedNoteJson>>(jsonStr)
                        .map { it.toSavedNote() }
                } catch (e: Exception) {
                    _savedNotes.value = emptyList()
                }
            }
            _currentNoteId.value = prefs[CURRENT_NOTE_ID]
        }
    }

    /**
     * Save settings to DataStore
     */
    suspend fun saveSettings(newSettings: TeleprompterSettings) {
        val normalizedSettings = newSettings.copy(autoScroll = true)
        _settings.value = normalizedSettings
        context.dataStore.edit { prefs ->
            prefs[FONT_SIZE_PRESET] = normalizedSettings.fontSizePreset.displayName
            prefs[PIP_FONT_SIZE_PRESET] = normalizedSettings.pipFontSizePreset.displayName
            prefs[OVERLAY_ASPECT_RATIO] = normalizedSettings.overlayAspectRatio.displayName
            prefs[SCROLL_SPEED] = normalizedSettings.scrollSpeed
            prefs[WORDS_PER_MINUTE] = normalizedSettings.wordsPerMinute
            prefs[LINES_PER_MINUTE] = normalizedSettings.linesPerMinute
            prefs[TIMER_MINUTES] = normalizedSettings.timerMinutes
            prefs[TIMER_SECONDS] = normalizedSettings.timerSeconds
            prefs[AUTO_SCROLL] = normalizedSettings.autoScroll
            prefs[THEME_PREFERENCE] = normalizedSettings.themePreference.displayName
            prefs[COUNTDOWN_SECONDS] = normalizedSettings.countdownSeconds
        }
    }

    /**
     * Save notes to DataStore
     */
    suspend fun saveNotes(newNotes: String) {
        _notes.value = newNotes
        context.dataStore.edit { prefs ->
            prefs[NOTES] = newNotes
        }
    }

    /**
     * Reset settings to defaults
     */
    suspend fun resetSettings() {
        saveSettings(TeleprompterSettings.DEFAULT)
    }

    /**
     * Clear all stored data
     */
    suspend fun clearAllData() {
        _settings.value = TeleprompterSettings.DEFAULT
        _notes.value = ""
        context.dataStore.edit { prefs ->
            prefs.clear()
        }
    }

    /**
     * Update individual setting properties
     */
    suspend fun updateFontSizePreset(preset: FontSizePreset) {
        saveSettings(_settings.value.copy(fontSizePreset = preset))
    }

    suspend fun updatePipFontSizePreset(preset: FontSizePreset) {
        saveSettings(_settings.value.copy(pipFontSizePreset = preset))
    }

    suspend fun updateOverlayAspectRatio(ratio: OverlayAspectRatio) {
        saveSettings(_settings.value.copy(overlayAspectRatio = ratio))
    }

    suspend fun updateWordsPerMinute(wpm: Int) {
        saveSettings(_settings.value.copy(wordsPerMinute = wpm))
    }

    suspend fun updateTimerMinutes(minutes: Int) {
        saveSettings(_settings.value.copy(timerMinutes = minutes))
    }

    suspend fun updateTimerSeconds(seconds: Int) {
        saveSettings(_settings.value.copy(timerSeconds = seconds))
    }

    suspend fun updateAutoScroll(enabled: Boolean) {
        saveSettings(_settings.value.copy(autoScroll = true))
    }

    suspend fun updateThemePreference(theme: ThemePreference) {
        saveSettings(_settings.value.copy(themePreference = theme))
    }

    suspend fun updateCountdownSeconds(seconds: Int) {
        saveSettings(_settings.value.copy(countdownSeconds = seconds))
    }

    suspend fun addSampleText() {
        saveNotes(DEFAULT_NOTE_TEXT)
    }

    // ==================== Saved Notes Methods ====================

    /**
     * Save current notes as a new note
     */
    suspend fun saveCurrentNote(title: String) {
        val trimmedContent = _notes.value.trim()
        if (trimmedContent.isEmpty()) return

        val note = SavedNote(
            title = title,
            content = _notes.value
        )
        val updatedNotes = listOf(note) + _savedNotes.value
        _savedNotes.value = updatedNotes
        _currentNoteId.value = note.id
        saveSavedNotes()
        saveCurrentNoteId()
    }

    /**
     * Update an existing saved note
     */
    suspend fun updateNote(id: String, title: String? = null, content: String? = null) {
        val index = _savedNotes.value.indexOfFirst { it.id == id }
        if (index == -1) return

        val currentNote = _savedNotes.value[index]
        val updatedNote = currentNote.copy(
            title = title ?: currentNote.title,
            content = content ?: currentNote.content,
            updatedAt = System.currentTimeMillis()
        )

        val updatedList = _savedNotes.value.toMutableList()
        updatedList[index] = updatedNote
        _savedNotes.value = updatedList
        saveSavedNotes()
    }

    /**
     * Save current changes to the currently loaded note
     */
    suspend fun saveChangesToCurrentNote() {
        val id = _currentNoteId.value ?: return
        updateNote(id, content = _notes.value)
    }

    /**
     * Load a saved note into the editor
     */
    suspend fun loadNote(note: SavedNote) {
        isLoadingNote = true
        _notes.value = note.content
        _currentNoteId.value = note.id
        saveNotes(note.content)
        saveCurrentNoteId()
        isLoadingNote = false
    }

    /**
     * Delete a saved note
     */
    suspend fun deleteNote(id: String) {
        _savedNotes.value = _savedNotes.value.filter { it.id != id }
        if (_currentNoteId.value == id) {
            _currentNoteId.value = null
            saveCurrentNoteId()
        }
        saveSavedNotes()
    }

    /**
     * Create a new empty note
     */
    suspend fun createNewNote() {
        isLoadingNote = true
        _notes.value = ""
        _currentNoteId.value = null
        saveNotes("")
        saveCurrentNoteId()
        isLoadingNote = false
    }

    /**
     * Get the currently loaded note if any
     */
    val currentNote: SavedNote?
        get() {
            val id = _currentNoteId.value ?: return null
            return _savedNotes.value.find { it.id == id }
        }

    /**
     * Check if current notes have unsaved changes
     */
    val hasUnsavedChanges: Boolean
        get() {
            val current = currentNote ?: return _notes.value.trim().isNotEmpty()
            return current.content != _notes.value
        }

    private suspend fun saveSavedNotes() {
        val jsonList = _savedNotes.value.map { SavedNoteJson.fromSavedNote(it) }
        val jsonStr = json.encodeToString(jsonList)
        context.dataStore.edit { prefs ->
            prefs[SAVED_NOTES] = jsonStr
        }
    }

    private suspend fun saveCurrentNoteId() {
        context.dataStore.edit { prefs ->
            val id = _currentNoteId.value
            if (id != null) {
                prefs[CURRENT_NOTE_ID] = id
            } else {
                prefs.remove(CURRENT_NOTE_ID)
            }
        }
    }
}

/**
 * JSON serializable version of SavedNote
 */
@kotlinx.serialization.Serializable
private data class SavedNoteJson(
    val id: String,
    val title: String,
    val content: String,
    val createdAt: Long,
    val updatedAt: Long
) {
    fun toSavedNote() = SavedNote(
        id = id,
        title = title,
        content = content,
        createdAt = createdAt,
        updatedAt = updatedAt
    )

    companion object {
        fun fromSavedNote(note: SavedNote) = SavedNoteJson(
            id = note.id,
            title = note.title,
            content = note.content,
            createdAt = note.createdAt,
            updatedAt = note.updatedAt
        )
    }
}
