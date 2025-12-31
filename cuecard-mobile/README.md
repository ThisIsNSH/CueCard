# CueCard Mobile

Mobile teleprompter app for iOS and Android with Picture-in-Picture support. Keep your speaker notes visible in a floating window while using other apps.

### Highlights

- **Cross-platform:** iOS and Android support
- **Picture-in-Picture:** Floating teleprompter visible over any app
- **Dynamic timing:** Use `[time mm:ss]` tags to control scroll speed
- **Note markers:** `[note content]` tags highlighted in pink
- **Google OAuth:** Sync notes from your CueCard account
- **Offline support:** Local persistence for notes and settings

### Architecture

- **Frontend:** vanilla HTML/TypeScript in `src/`
- **Tauri shell:** `src-tauri/` Rust crate handles auth, storage, and segment parsing
- **Native plugins:**
  - iOS: Swift PiP manager using `AVPictureInPictureController`
  - Android: Kotlin PiP manager using native PiP mode
- **Local store:** `tauri-plugin-store` caches tokens and preferences

### Platform-Specific Features

| Feature | iOS | Android |
|---------|-----|---------|
| **PiP Mode** | `AVPictureInPictureController` + `AVSampleBufferDisplayLayer` | `enterPictureInPictureMode` (API 26+) |
| **Min Version** | iOS 15.0+ | Android 8.0+ (API 26) |
| **Play/Pause** | Native PiP controls | Remote actions via broadcast receiver |
| **Timer Display** | Fixed top-left overlay | Canvas rendering |

### Teleprompter Format

```
Welcome everyone!                  <- No timer, uses default speed

[time 00:30]                       <- This section scrolls in 30 seconds
I'm excited to be here today.      <- Section start
[note smile and pause]             <- Displayed in pink, section end

[time 01:00]                       <- This section scrolls in 1 minute
Now let's talk about our main topic.  <- Section start

Final thoughts.
Thank you!                         <- Section end (until next [time] or EOF)
```

Sections are delimited by `[time]` tags. All content between one `[time]` tag and the next belongs to the same section. New lines do not create new sections.

### Firebase Configuration

The mobile app requires a `firebase-config.json` file in the `src-tauri/` directory.

1. Copy the example file:
   ```bash
   cd src-tauri
   cp firebase-config.example.json firebase-config.json
   ```
2. Fill in values from your Firebase project settings.

**Note:** The build will fail if `firebase-config.json` is missing.

### Prerequisites

**For iOS development:**
- macOS with Xcode 15+
- Xcode Command Line Tools
- CocoaPods (optional)

**For Android development:**
- Android Studio
- Android SDK (API 26+)
- Android NDK
- Java 17+

### Run in Development

#### iOS Simulator

```bash
# Run on default iOS simulator
npm run tauri ios dev

# Run on a specific simulator
npm run tauri ios dev -- --target "iPhone 15 Pro"

# Open in Xcode (for physical device testing)
npm run tauri ios dev -- --open
```

**Note:** PiP functionality requires a physical iOS device. The simulator has limited PiP support.

#### Android Emulator

```bash
# List available Android emulators
emulator -list-avds

# Start an emulator
emulator -avd <your_avd_name>

# Run on connected emulator/device
npm run tauri android dev

# Open in Android Studio
npm run tauri android dev -- --open
```

**Requirements:**
- Emulator must be API 26+ (Android 8.0+) for PiP support
- Enable PiP permission: Settings > Apps > CueCard > Picture-in-picture > Allow

### Build for Production

#### iOS

```bash
# Build for iOS device (release)
npm run tauri ios build

# Build for App Store
npm run tauri ios build -- --export-method app-store-connect
```

Build artifacts: `src-tauri/gen/apple/build/`

#### Android

```bash
# Build APK
npm run tauri android build

# Build for Play Store (AAB)
npm run tauri android build -- --aab
```

Build artifacts: `src-tauri/gen/android/app/build/outputs/`

### Testing Checklist

1. **Basic functionality:**
   - [ ] App launches successfully
   - [ ] Can paste notes into the editor
   - [ ] Settings (font size, scroll speed, opacity) work

2. **Picture-in-Picture:**
   - [ ] Tap "Start Teleprompter" enters PiP mode
   - [ ] Text scrolls smoothly in PiP window
   - [ ] Play/pause controls work
   - [ ] Close PiP returns to app

3. **Timing features:**
   - [ ] `[time mm:ss]` tags control scroll speed
   - [ ] Timer countdown appears in top-left
   - [ ] `[note content]` appears in pink

4. **Authentication:**
   - [ ] Google OAuth flow completes
   - [ ] Notes sync from cloud

### Project Structure

```
cuecard-mobile/
├── src/
│   ├── main.ts                    # Frontend entry point
│   └── styles.css                 # UI styling
├── src-tauri/
│   ├── src/
│   │   ├── lib.rs                 # Main Rust code
│   │   ├── teleprompter.rs        # Segment parsing logic
│   │   ├── ios_pip.rs             # iOS PiP bridge
│   │   └── android_pip.rs         # Android PiP bridge
│   ├── gen/
│   │   ├── apple/
│   │   │   └── Sources/
│   │   │       ├── TeleprompterPiPManager.swift
│   │   │       └── TeleprompterBridge.swift
│   │   └── android/
│   │       └── app/src/main/java/.../
│   │           ├── TeleprompterPiPManager.kt
│   │           └── TeleprompterBridge.kt
│   └── tauri.conf.json            # Tauri configuration
└── package.json
```

### Troubleshooting

**iOS: PiP not starting**
- Ensure audio session is active (required for PiP)
- Check device is iOS 15.0+
- PiP must be enabled in device settings

**Android: PiP not working**
- Verify API level is 26+
- Check PiP permission in app settings
- Some OEMs restrict PiP functionality

**Build fails with missing firebase-config.json**
- Copy the example config: `cp src-tauri/firebase-config.example.json src-tauri/firebase-config.json`
- Fill in your Firebase credentials
