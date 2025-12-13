# CueCard App

Desktop application for macOS that displays speaker notes in an always-on-top transparent window.

## Features

- Always-on-top window visible across all workspaces
- Screenshot protection (notes won't appear in screen shares)
- Google OAuth for syncing notes
- Auto-update support

## Development

### Prerequisites

- Rust 1.70+
- Node.js 18+ (for frontend)
- Xcode Command Line Tools

### Setup

1. Create `.env` file in the project root (see `.env.example`):
   ```
   GOOGLE_CLIENT_ID=your_client_id.apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET=your_client_secret
   FIRESTORE_PROJECT_ID=your-project-id
   ```

2. Install Tauri CLI:
   ```bash
   cargo install tauri-cli
   ```

### Run in Development

```bash
cargo tauri dev
```

### Build for Production

```bash
cargo tauri build
```

Output is written to `src-tauri/target/release/bundle/`.

## Release Process

### macOS

1. Build the release:
   ```bash
   cargo tauri build
   ```

2. Locate build artifacts in `src-tauri/target/release/bundle/`:
   - `dmg/CueCard_<version>_aarch64.dmg` - Disk image for distribution
   - `macos/CueCard.app` - Application bundle

3. For auto-update support:
   - Generate signing keys (first time only):
     ```bash
     cargo tauri signer generate -w ~/.tauri/cuecard.key
     ```
   - Build with signing:
     ```bash
     TAURI_SIGNING_PRIVATE_KEY=$(cat ~/.tauri/cuecard.key) cargo tauri build
     ```
   - This generates `latest.json` for the updater

4. Create GitHub Release:
   - Tag the release: `git tag v<version>`
   - Push tag: `git push origin v<version>`
   - Create release on GitHub
   - Upload:
     - `CueCard_<version>_aarch64.dmg`
     - `latest.json` (for auto-update)

### Signing (Optional)

For distribution outside the App Store, you may want to notarize the app:

1. Codesign the app:
   ```bash
   codesign --deep --force --verify --verbose \
     --sign "Developer ID Application: Your Name (TEAM_ID)" \
     src-tauri/target/release/bundle/macos/CueCard.app
   ```

2. Notarize with Apple:
   ```bash
   xcrun notarytool submit CueCard.dmg \
     --apple-id your@email.com \
     --team-id TEAM_ID \
     --password @keychain:AC_PASSWORD
   ```

### Notes

- The `target/` folder is gitignored (build artifacts)
- Environment variables are embedded at build time via `build.rs`
- Auto-updater checks `https://github.com/thisisnsh/cuecard/releases/latest/download/latest.json`
- Version is managed in `src-tauri/tauri.conf.json` and `src-tauri/Cargo.toml`
