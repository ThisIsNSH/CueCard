# CueCard

Speaker notes visible only to you — for presentations, meetings, dates and everything.

CueCard is a macOS desktop application that displays your speaker notes in a floating window that stays on top of all other applications and is invisible to screen capture and recordings. Perfect for presentations, video calls, and any situation where you need a discreet teleprompter.

## Features

- **Screen Capture Protection** - Notes are invisible in screenshots and screen recordings
- **Always On Top** - Floating window stays visible over all apps including fullscreen presentations
- **Google Slides Integration** - Automatically syncs speaker notes from Google Slides presentations
- **Manual Notes** - Paste your own notes for any occasion
- **Timer Support** - Add countdown timers to your notes with `[time mm:ss]` syntax
- **Adjustable Transparency** - Control window opacity to see content behind
- **Non-Activating Window** - Click-through to other apps without losing focus

## Project Structure

```
cuecard/
├── cuecard-app/          # Tauri desktop application (macOS)
│   ├── src/              # Frontend (HTML, CSS, JavaScript)
│   └── src-tauri/        # Rust backend
└── extension/            # Browser extension (Chrome, Safari)
    ├── src/              # Extension source code
    └── manifests/        # Browser-specific manifests
```

## Prerequisites

- **macOS 10.13+** (High Sierra or later)
- **Node.js 18+**
- **Rust** (latest stable)
- **Xcode** (for Safari extension and macOS builds)

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/your-username/cuecard.git
cd cuecard
```

### 2. Configure environment variables

Copy the example environment file and fill in your credentials:

```bash
cp .env.example .env
```

Edit `.env` with your Google OAuth credentials and Firestore project ID:

```env
GOOGLE_CLIENT_ID=your_client_id_here.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_client_secret_here
FIRESTORE_PROJECT_ID=your-project-id
```

**Getting Google OAuth Credentials:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create a new OAuth 2.0 Client ID
3. Set the authorized redirect URI to `http://127.0.0.1:3642/oauth/callback`
4. Enable the Google Slides API for your project

### 3. Build and run the desktop app

```bash
cd cuecard-app
npm install
npm run tauri dev
```

### 4. Build the browser extension

```bash
cd extension
npm run build
```

## Installation

### Desktop App (macOS)

Build the production app:

```bash
cd cuecard-app
npm run tauri build
```

The built `.app` and `.dmg` files will be in `cuecard-app/src-tauri/target/release/bundle/`.

### Browser Extension

#### Chrome / Edge

1. Run `npm run build` in the extension directory
2. Open `chrome://extensions` (or `edge://extensions`)
3. Enable "Developer mode"
4. Click "Load unpacked"
5. Select the `extension/dist/chrome` folder

#### Safari

1. Run `npm run build:safari` in the extension directory
2. Open the generated Xcode project: `open extension/dist/safari-xcode/CueCard\ Extension/CueCard\ Extension.xcodeproj`
3. Select your development team in Xcode
4. Build and run (Cmd+R)
5. Enable the extension in Safari > Preferences > Extensions

## Usage

### With Google Slides

1. Sign in with Google in the CueCard app
2. Grant access to read your Google Slides presentations
3. Install the browser extension
4. Open a Google Slides presentation in your browser
5. Your speaker notes will automatically appear in CueCard

### With Manual Notes

1. Click "Your Notes" in the CueCard app
2. Paste your notes into the text area
3. Use special syntax for timers: `[time 02:00]` for a 2-minute countdown

### Timer Syntax

Add countdown timers to your notes:

```
[time 01:30] Introduction and greeting
[time 03:00] Main content
[time 00:30] Wrap up and questions
```

Timers are cumulative - each `[time]` adds to the total presentation time.

### Emotion Tags

Add visual cues for delivery:

```
[emotion pause] Take a breath here
[emotion emphasize] Key point coming up
```

## Development

### Desktop App

```bash
cd cuecard-app
npm run tauri dev    # Run in development mode
npm run tauri build  # Build for production
```

### Extension

```bash
cd extension
npm run build              # Build for all browsers
npm run build:chrome       # Build for Chrome only
npm run build:safari       # Build for Safari only
npm run release            # Create release packages
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Privacy

CueCard is designed with privacy in mind:
- Speaker notes are never stored on our servers
- Google authentication is used only to access your own presentations
- The app runs entirely locally on your machine
- Screen capture protection ensures your notes stay private
