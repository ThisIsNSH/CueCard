# CueCard Mobile

Native iOS and Android apps for CueCard - your AI-powered flashcard companion.

## Features

- **Google Authentication** via Firebase Auth SDK (native)
- **Firebase Analytics** for usage tracking
- **SwiftUI** (iOS) and **Jetpack Compose** (Android) for modern UI
- **Material 3** design system on Android

## Bundle IDs

| Platform | Bundle ID |
|----------|-----------|
| iOS | `com.thisisnsh.cuecard.ios` |
| Android | `com.thisisnsh.cuecard.android` |

## Firebase Setup

Both apps require Firebase configuration files. Download these from the [Firebase Console](https://console.firebase.google.com):

### iOS Setup

1. Go to Firebase Console → Project Settings → Your Apps
2. Add an iOS app with bundle ID: `com.thisisnsh.cuecard.ios`
3. Download `GoogleService-Info.plist`
4. Replace `ios/CueCard/CueCard/GoogleService-Info.plist` with the downloaded file
5. Add URL scheme for Google Sign-In:
   - Copy `REVERSED_CLIENT_ID` from `GoogleService-Info.plist`
   - It's already configured in `Info.plist` via `$(REVERSED_CLIENT_ID)`

### Android Setup

1. Go to Firebase Console → Project Settings → Your Apps
2. Add an Android app with package name: `com.thisisnsh.cuecard.android`
3. Download `google-services.json`
4. Replace `android/app/google-services.json` with the downloaded file
5. Update Web Client ID in `LoginScreen.kt`:
   - Find your Web Client ID in Firebase Console → Authentication → Sign-in method → Google
   - Replace `YOUR_WEB_CLIENT_ID` in the code

## Prerequisites

### iOS Development
- macOS
- Xcode 15.0+
- iOS 17.0+ deployment target
- Apple Developer account (for device testing)

### Android Development
- Android Studio Hedgehog (2023.1.1) or newer
- JDK 17
- Android SDK 34
- Min SDK: 26 (Android 8.0)

## Building

### iOS

```bash
# Open in Xcode
open ios/CueCard/CueCard.xcodeproj

# Or build from command line
cd ios/CueCard
xcodebuild -scheme CueCard -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

**First build:** Xcode will automatically fetch Swift Package dependencies (Firebase SDK, GoogleSignIn).

### Android

```bash
# Open in Android Studio
open -a "Android Studio" android/

# Or build from command line
cd android
./gradlew assembleDebug
```

**First build:** Gradle will automatically download dependencies.

## Running

### iOS Simulator

1. Open `ios/CueCard/CueCard.xcodeproj` in Xcode
2. Select target device (e.g., iPhone 15 Pro)
3. Press Cmd+R or click Run

### Android Emulator

1. Open `android/` folder in Android Studio
2. Create/select an AVD (API 26+)
3. Press Run or Shift+F10

## Architecture

### iOS (SwiftUI)

```
CueCardApp.swift          # App entry point, Firebase initialization
├── ContentView.swift     # Root view, auth state routing
├── Views/
│   ├── LoginView.swift   # Google Sign-In UI
│   ├── HomeView.swift    # Main flashcard view
│   └── ProfileView.swift # User profile sheet
└── Services/
    └── AuthenticationService.swift  # Firebase Auth + Google Sign-In
```

### Android (Jetpack Compose)

```
CueCardApplication.kt     # Application class, Firebase init
├── MainActivity.kt       # Single activity
├── ui/
│   ├── screens/
│   │   ├── MainScreen.kt     # Navigation host
│   │   ├── LoginScreen.kt    # Google Sign-In UI
│   │   ├── HomeScreen.kt     # Main flashcard view
│   │   └── ProfileSheet.kt   # User profile bottom sheet
│   └── theme/
│       └── Theme.kt          # Material 3 theming
└── services/
    └── AuthenticationService.kt  # Firebase Auth + Credential Manager
```

## Dependencies

### iOS (Swift Package Manager)

- `firebase-ios-sdk` - Firebase Analytics & Auth
- `GoogleSignIn-iOS` - Google Sign-In

### Android (Gradle)

- Firebase BOM 32.7.0
  - `firebase-analytics-ktx`
  - `firebase-auth-ktx`
- Jetpack Compose BOM 2023.10.01
- Google Identity Services (Credential Manager)
- Coil for image loading
