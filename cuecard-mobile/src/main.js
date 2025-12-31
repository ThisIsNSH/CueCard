// =============================================================================
// TAURI API INITIALIZATION
// =============================================================================

// Check if Tauri is available
if (!window.__TAURI__) {
  console.error("Tauri runtime not available! Make sure you're running the app with 'npm run tauri dev' or as a built Tauri app.");
}

const { invoke } = window.__TAURI__?.core || {};
const { listen } = window.__TAURI__?.event || {};

// =============================================================================
// STATE
// =============================================================================

let _currentView = "signin";
let isEditMode = true;
let timerState = "stopped";
let timerIntervals = [];
let isAndroid = false;
let isIOS = false;

// Settings
let settings = {
  fontSize: 16,
  scrollSpeed: 1.0,
  opacity: 100,
};

// =============================================================================
// DOM ELEMENTS
// =============================================================================

// Views
let viewSignin;
let viewNotes;
let viewSettings;

// Sign in
let btnSignin;

// Notes view
let userGreeting;
let btnSettings;
let notesInput;
let notesInputHighlight;
let notesInputWrapper;
let btnEdit;
let btnStartFloating;
let timerControls;
let btnTimerStart;
let btnTimerPause;
let btnTimerReset;

// Settings view
let btnBack;
let btnSignout;
let fontSizeSlider;
let fontSizeValue;
let scrollSpeedSlider;
let scrollSpeedValue;
let scrollSpeedGroup;
let opacitySlider;
let opacityValue;

// =============================================================================
// INITIALIZATION
// =============================================================================

window.addEventListener("DOMContentLoaded", async () => {
  initializeElements();
  detectPlatform();
  setupEventListeners();
  setupNotesInputHighlighting();
  await loadSettings();
  await loadSavedNotes();
  await checkAuthStatus();
  setupDeepLinkListener();
});

function initializeElements() {
  // Views
  viewSignin = document.getElementById("view-signin");
  viewNotes = document.getElementById("view-notes");
  viewSettings = document.getElementById("view-settings");

  // Sign in
  btnSignin = document.getElementById("btn-signin");

  // Notes view
  userGreeting = document.getElementById("user-greeting");
  btnSettings = document.getElementById("btn-settings");
  notesInput = document.getElementById("notes-input");
  notesInputHighlight = document.getElementById("notes-input-highlight");
  notesInputWrapper = document.getElementById("notes-input-wrapper");
  btnEdit = document.getElementById("btn-edit");
  btnStartFloating = document.getElementById("btn-start-floating");
  timerControls = document.getElementById("timer-controls");
  btnTimerStart = document.getElementById("btn-timer-start");
  btnTimerPause = document.getElementById("btn-timer-pause");
  btnTimerReset = document.getElementById("btn-timer-reset");

  // Settings view
  btnBack = document.getElementById("btn-back");
  btnSignout = document.getElementById("btn-signout");
  fontSizeSlider = document.getElementById("font-size-slider");
  fontSizeValue = document.getElementById("font-size-value");
  scrollSpeedSlider = document.getElementById("scroll-speed-slider");
  scrollSpeedValue = document.getElementById("scroll-speed-value");
  scrollSpeedGroup = document.getElementById("scroll-speed-group");
  opacitySlider = document.getElementById("opacity-slider");
  opacityValue = document.getElementById("opacity-value");
}

function detectPlatform() {
  // Detect platform from Tauri
  const platform = window.__TAURI_INTERNALS__?.metadata?.currentPlatform;
  isAndroid = platform === "android";
  isIOS = platform === "ios";

  // Fallback detection via user agent
  if (!isAndroid && !isIOS) {
    const ua = navigator.userAgent.toLowerCase();
    isAndroid = ua.includes("android");
    isIOS = /iphone|ipad|ipod/.test(ua);
  }

  // Hide scroll speed on Android (only for iOS teleprompter)
  if (isAndroid && scrollSpeedGroup) {
    scrollSpeedGroup.classList.add("hidden");
  }
}

// =============================================================================
// EVENT LISTENERS
// =============================================================================

function setupEventListeners() {
  // Sign in button
  btnSignin?.addEventListener("click", handleSignIn);

  // Settings button
  btnSettings?.addEventListener("click", () => showView("settings"));

  // Back button
  btnBack?.addEventListener("click", () => showView("notes"));

  // Sign out button
  btnSignout?.addEventListener("click", handleSignOut);

  // Edit button
  btnEdit?.addEventListener("click", toggleEditMode);

  // Start PiP teleprompter button
  btnStartFloating?.addEventListener("click", startPiPTeleprompter);

  // Timer buttons
  btnTimerStart?.addEventListener("click", startTimer);
  btnTimerPause?.addEventListener("click", pauseTimer);
  btnTimerReset?.addEventListener("click", resetTimer);

  // Settings sliders
  fontSizeSlider?.addEventListener("input", handleFontSizeChange);
  scrollSpeedSlider?.addEventListener("input", handleScrollSpeedChange);
  opacitySlider?.addEventListener("input", handleOpacityChange);
}

// =============================================================================
// VIEW MANAGEMENT
// =============================================================================

function showView(view) {
  _currentView = view;

  // Hide all views
  viewSignin?.classList.remove("active");
  viewNotes?.classList.remove("active");
  viewSettings?.classList.remove("active");

  // Show selected view
  switch (view) {
    case "signin":
      viewSignin?.classList.add("active");
      break;
    case "notes":
      viewNotes?.classList.add("active");
      break;
    case "settings":
      viewSettings?.classList.add("active");
      break;
  }
}

// =============================================================================
// AUTHENTICATION
// =============================================================================

async function checkAuthStatus() {
  if (!invoke) return;
  try {
    const isAuthenticated = await invoke("get_auth_status");
    if (isAuthenticated) {
      const userInfo = await invoke("get_user_info");
      updateGreeting(userInfo?.name || "");
      showView("notes");
    } else {
      showView("signin");
    }
  } catch (error) {
    console.error("Error checking auth status:", error);
    showView("signin");
  }
}

async function handleSignIn() {
  console.log("handleSignIn called");
  console.log("invoke available:", !!invoke);
  if (!invoke) {
    console.error("invoke is not available!");
    return;
  }
  try {
    console.log("Calling start_login...");
    await invoke("start_login");
    console.log("start_login completed successfully");
  } catch (error) {
    console.error("Error starting login:", error);
  }
}

async function handleSignOut() {
  if (!invoke) return;
  try {
    await invoke("logout");
    showView("signin");
  } catch (error) {
    console.error("Error signing out:", error);
  }
}

function updateGreeting(name) {
  if (!userGreeting) return;
  const hour = new Date().getHours();
  let greeting = "Good evening";
  if (hour >= 5 && hour < 12) greeting = "Good morning";
  else if (hour >= 12 && hour < 17) greeting = "Good afternoon";

  const firstName = name.split(" ")[0] || "";
  userGreeting.textContent = firstName ? `${greeting}, ${firstName}` : greeting;
}

function setupDeepLinkListener() {
  if (!listen) return;
  listen("auth-status", (event) => {
    const { authenticated, user_name } = event.payload;
    if (authenticated) {
      updateGreeting(user_name || "");
      showView("notes");
    }
  });
}

// =============================================================================
// NOTES INPUT AND SYNTAX HIGHLIGHTING
// =============================================================================

function setupNotesInputHighlighting() {
  if (!notesInput || !notesInputHighlight) return;

  notesInput.addEventListener("input", () => {
    updateHighlight();
    saveNotes();
    updateButtonVisibility();
  });

  notesInput.addEventListener("scroll", () => {
    if (notesInputHighlight) {
      notesInputHighlight.scrollTop = notesInput.scrollTop;
    }
  });

  // Initial update
  updateHighlight();
}

function updateHighlight() {
  if (!notesInput || !notesInputHighlight) return;

  const text = notesInput.value;
  if (!text) {
    notesInputHighlight.innerHTML = "";
    return;
  }

  const highlighted = highlightNotes(text);
  notesInputHighlight.innerHTML = highlighted;
}

function highlightNotes(text) {
  // Normalize line breaks
  let safe = text
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .replace(/\u2028/g, "\n")
    .replace(/\u2029/g, "\n");

  // Escape HTML
  safe = escapeHtml(safe);

  let cumulativeTime = 0;

  // Pattern for [time mm:ss] syntax
  const timePattern = /\[time\s+(\d{1,2}):(\d{2})\]/gi;

  // Pattern for [note ...] syntax
  const notePattern = /\[note\s+([^\]]+)\]/gi;

  // Replace [time mm:ss]
  safe = safe.replace(timePattern, (_match, minutes, seconds) => {
    const timeInSeconds = parseInt(minutes) * 60 + parseInt(seconds);
    cumulativeTime += timeInSeconds;

    const displayMinutes = Math.floor(cumulativeTime / 60);
    const displaySeconds = cumulativeTime % 60;
    const displayTime = `${String(displayMinutes).padStart(2, "0")}:${String(displaySeconds).padStart(2, "0")}`;

    return `<span class="timestamp" data-time="${cumulativeTime}">[${displayTime}]</span>`;
  });

  // Replace [note ...]
  safe = safe.replace(notePattern, (_match, note) => {
    return `<span class="action-tag">[${note}]</span>`;
  });

  // Convert line breaks
  safe = safe.replace(/\n/g, "<br>");

  return safe;
}

function escapeHtml(text) {
  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

// =============================================================================
// EDIT MODE
// =============================================================================

function toggleEditMode() {
  isEditMode = !isEditMode;

  if (isEditMode) {
    notesInputWrapper?.classList.add("edit-mode");
    if (notesInput) notesInput.readOnly = false;
    if (btnEdit) btnEdit.textContent = "Save Note";
    notesInput?.focus();
  } else {
    notesInputWrapper?.classList.remove("edit-mode");
    if (notesInput) notesInput.readOnly = true;
    if (btnEdit) btnEdit.textContent = "Edit Note";
  }

  resetTimer();
  updateButtonVisibility();
}

function updateButtonVisibility() {
  if (!notesInput) return;

  const hasContent = notesInput.value.trim().length > 0;
  const hasTimePattern = /\[time\s+\d{1,2}:\d{2}\]/i.test(notesInput.value);

  // Edit button
  if (hasContent) {
    btnEdit?.classList.remove("hidden");
  } else {
    btnEdit?.classList.add("hidden");
  }

  // Start floating button
  if (hasContent && !isEditMode) {
    btnStartFloating?.classList.remove("hidden");
  } else {
    btnStartFloating?.classList.add("hidden");
  }

  // Timer controls (Android only)
  if (isAndroid && hasTimePattern && !isEditMode) {
    timerControls?.classList.remove("hidden");
    updateTimerButtonVisibility();
  } else {
    timerControls?.classList.add("hidden");
  }
}

// =============================================================================
// TIMER
// =============================================================================

function startTimer() {
  if (timerState === "running") return;

  timerState = "running";
  updateTimerButtonVisibility();

  const timestamps = notesInputHighlight?.querySelectorAll(".timestamp[data-time]");
  if (!timestamps) return;

  timestamps.forEach((timestamp) => {
    let remainingSeconds = parseInt(
      timestamp.getAttribute("data-remaining") || timestamp.getAttribute("data-time") || "0"
    );

    const interval = window.setInterval(() => {
      if (timerState !== "running") {
        clearInterval(interval);
        return;
      }

      remainingSeconds--;
      timestamp.setAttribute("data-remaining", String(remainingSeconds));

      const minutes = Math.floor(Math.abs(remainingSeconds) / 60);
      const seconds = Math.abs(remainingSeconds) % 60;
      const displayTime = `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;

      if (remainingSeconds < 0) {
        timestamp.textContent = `[-${displayTime}]`;
        timestamp.classList.add("time-overtime");
        timestamp.classList.remove("time-warning");
      } else if (remainingSeconds < 10) {
        timestamp.textContent = `[${displayTime}]`;
        timestamp.classList.add("time-warning");
        timestamp.classList.remove("time-overtime");
      } else {
        timestamp.textContent = `[${displayTime}]`;
        timestamp.classList.remove("time-warning", "time-overtime");
      }
    }, 1000);

    timerIntervals.push(interval);
  });
}

function pauseTimer() {
  if (timerState !== "running") return;

  timerState = "paused";
  stopAllTimers();
  updateTimerButtonVisibility();
}

function resetTimer() {
  stopAllTimers();
  timerState = "stopped";

  const timestamps = notesInputHighlight?.querySelectorAll(".timestamp[data-time]");
  if (!timestamps) return;

  timestamps.forEach((timestamp) => {
    const originalTime = parseInt(timestamp.getAttribute("data-time") || "0");
    timestamp.setAttribute("data-remaining", String(originalTime));

    const minutes = Math.floor(originalTime / 60);
    const seconds = originalTime % 60;
    const displayTime = `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;

    timestamp.textContent = `[${displayTime}]`;
    timestamp.classList.remove("time-warning", "time-overtime");
  });

  updateTimerButtonVisibility();
}

function stopAllTimers() {
  timerIntervals.forEach((interval) => clearInterval(interval));
  timerIntervals = [];
}

function updateTimerButtonVisibility() {
  switch (timerState) {
    case "stopped":
      btnTimerStart?.classList.remove("hidden");
      btnTimerPause?.classList.add("hidden");
      btnTimerReset?.classList.add("hidden");
      break;
    case "running":
      btnTimerStart?.classList.add("hidden");
      btnTimerPause?.classList.remove("hidden");
      btnTimerReset?.classList.remove("hidden");
      break;
    case "paused":
      btnTimerStart?.classList.remove("hidden");
      btnTimerPause?.classList.add("hidden");
      btnTimerReset?.classList.remove("hidden");
      break;
  }
}

// =============================================================================
// PIP TELEPROMPTER
// =============================================================================

async function startPiPTeleprompter() {
  if (!notesInput || !invoke) return;

  const content = notesInput.value;
  if (!content.trim()) return;

  try {
    await invoke("start_pip_teleprompter", {
      content,
      fontSize: settings.fontSize,
      defaultScrollSpeed: settings.scrollSpeed,
      opacity: settings.opacity / 100,
    });
  } catch (error) {
    console.error("Error starting PiP teleprompter:", error);
  }
}

// =============================================================================
// SETTINGS
// =============================================================================

function handleFontSizeChange() {
  if (!fontSizeSlider || !fontSizeValue) return;

  const value = parseInt(fontSizeSlider.value);
  settings.fontSize = value;
  fontSizeValue.textContent = `${value}px`;

  // Update notes preview font size
  if (notesInput) notesInput.style.fontSize = `${value}px`;
  if (notesInputHighlight) notesInputHighlight.style.fontSize = `${value}px`;

  saveSettings();
}

function handleScrollSpeedChange() {
  if (!scrollSpeedSlider || !scrollSpeedValue) return;

  const value = parseInt(scrollSpeedSlider.value) / 10;
  settings.scrollSpeed = value;
  scrollSpeedValue.textContent = `${value.toFixed(1)}x`;

  saveSettings();
}

function handleOpacityChange() {
  if (!opacitySlider || !opacityValue) return;

  const value = parseInt(opacitySlider.value);
  settings.opacity = value;
  opacityValue.textContent = `${value}%`;

  saveSettings();
}

async function loadSettings() {
  if (!invoke) return;
  try {
    const savedSettings = await invoke("get_settings");
    if (savedSettings) {
      settings = savedSettings;

      // Update UI
      if (fontSizeSlider) fontSizeSlider.value = String(settings.fontSize);
      if (fontSizeValue) fontSizeValue.textContent = `${settings.fontSize}px`;
      if (scrollSpeedSlider) scrollSpeedSlider.value = String(settings.scrollSpeed * 10);
      if (scrollSpeedValue) scrollSpeedValue.textContent = `${settings.scrollSpeed.toFixed(1)}x`;
      if (opacitySlider) opacitySlider.value = String(settings.opacity);
      if (opacityValue) opacityValue.textContent = `${settings.opacity}%`;

      // Apply font size
      if (notesInput) notesInput.style.fontSize = `${settings.fontSize}px`;
      if (notesInputHighlight) notesInputHighlight.style.fontSize = `${settings.fontSize}px`;
    }
  } catch (error) {
    console.log("No saved settings found, using defaults");
  }
}

async function saveSettings() {
  if (!invoke) return;
  try {
    await invoke("save_settings", { settings });
  } catch (error) {
    console.error("Error saving settings:", error);
  }
}

// =============================================================================
// NOTES PERSISTENCE
// =============================================================================

async function loadSavedNotes() {
  if (!invoke) return;
  try {
    const savedNotes = await invoke("get_notes");
    if (savedNotes && notesInput) {
      notesInput.value = savedNotes;
      updateHighlight();
      updateButtonVisibility();
    }
  } catch (error) {
    console.log("No saved notes found");
  }
}

async function saveNotes() {
  if (!notesInput || !invoke) return;

  try {
    await invoke("save_notes", { content: notesInput.value });
  } catch (error) {
    console.error("Error saving notes:", error);
  }
}
