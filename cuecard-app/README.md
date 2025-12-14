# CueCard App

Desktop client built with Tauri that keeps your speaker notes on top of every other window while staying invisible to screen sharing, screenshots, and recordings.

### Highlights

- Always-on-top window visible across all workspaces
- Screenshot protection (notes won't appear in screen shares)
- Google OAuth for syncing notes
- Auto-update support

### Architecture

- **Frontend:** vanilla HTML/JS in `src/`
- **Tauri shell:** `src-tauri/` Rust crate exposes commands for auth, timers, notes, and window control
- **Local store:** `tauri-plugin-store` caches Google and Firebase tokens, timers, and preferences
- **Firebase REST bridge:** Rust code exchanges Google OAuth tokens for Firebase custom tokens and fetches notes from Firestore

### Firebase Configuration

The desktop app expects a `firebase-config.json` file that mirrors `firebase-config-example.json`. It is packaged as part of the Tauri bundle so the Rust backend can bootstrap Firebase SDK calls.

1. Copy the example file:
   ```bash
   cp firebase-config-example.json firebase-config.json
   ```
2. Fill every field under the `firebase` key with the values from your Firebase project settings (Project Settings → General → Your apps).

Without this file the app cannot exchange Google tokens for Firebase ID tokens, so syncing notes from the browser extension will fail.

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
