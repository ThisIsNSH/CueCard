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
npm run tauri dev
```

### Build for Production

```bash
npm run tauri build
```

Output is written to `src-tauri/target/release/bundle/`.

## Release Process

### MacOS (Signing + Updater)

1. Generate signing keys (first time only):
   ```bash
   npm run tauri signer generate -- -w ~/.tauri/cuecard.key
   ``` 
   
2. Build with signing:
   ```bash
   APPLE_SIGNING_IDENTITY="" \
   APPLE_ID="" \
   APPLE_PASSWORD="" \
   APPLE_TEAM_ID="" \
   TAURI_SIGNING_PRIVATE_KEY="" \
   TAURI_SIGNING_PRIVATE_KEY_PASSWORD="" \
   npm run tauri build -- --target universal-apple-darwin
   ```
   This generates `latest.json` for the updater

3. Locate build artifacts in `src-tauri/target/universal-apple-darwin/release/bundle/`:
   - `dmg/CueCard_<version>_universal.dmg` - Disk image for distribution
   - `macos/CueCard.app` - Application bundle

4. Create GitHub Release:
   - Tag the release: `git tag v<version>`
   - Push tag: `git push origin v<version>`
   - Create release on GitHub
   - Upload:
     - `CueCard_<version>_universal.dmg`
     - `latest.json` (for auto-update)

### Notes

- The `target/` folder is gitignored (build artifacts)
- Environment variables are embedded at build time via `build.rs`
- Auto-updater checks `https://github.com/thisisnsh/cuecard/releases/latest/download/latest.json`
- Version is managed in `src-tauri/tauri.conf.json` and `src-tauri/Cargo.toml`
