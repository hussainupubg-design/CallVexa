# CallVexa iOS Application (.ipa)

Complete iOS Native Application wrapper for **CallVexa — https://callvexa.us** built with **Capacitor**, **Native Swift**, and **Codemagic CI/CD**.

---

## 📱 App Highlights & Architecture

- **Always in Sync (Remote URL Architecture)**: The native app loads `https://callvexa.us` directly via WKWebView. Any updates to the live website, dialer features, or web endpoints are immediately reflected without requiring an app store update or rebuild.
- **WebRTC & Twilio Calling Integration**: Configured with `NSMicrophoneUsageDescription` and custom `WKUIDelegate` media capture permissions to automatically authorize microphone audio capture for browser dialer and incoming/outgoing calls.
- **Background Audio & VoIP Modes**: Configured with `UIBackgroundModes` (`audio`, `voip`, and `remote-notification`) and initialized with `AVAudioSession` set to `.playAndRecord` and `.voiceChat` so active calls survive when the app transitions to the background or when the phone screen is locked.
- **Native CallKit Screen + In-App Incoming Banner**:
  - Implements `CallKitManager.swift` (`CXProvider` + `CXCallController`) to present the native iOS incoming call screen with full Answer / Decline capabilities.
  - In-app incoming banner remains fully functional and synced with CallKit through a bidirectional JavaScript bridge (`window.CallVexaNativeBridge`).
- **Media & Inboxes**: Configured with `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, and `NSPhotoLibraryAddUsageDescription` for photo uploads in WhatsApp and SMS inboxes.
- **External Links Handler**: External URLs (`wa.me`, `whatsapp:`, `tel:`, `sms:`, `mailto:`) automatically open in external native iOS applications rather than getting blocked in the webview.
- **Offline / Zero-Connection Fallback**: Bundled local offline UI (`www/index.html` & `www/offline.html`) with matching CallVexa theme, live network status badge, and auto-retry listener powered by `NWPathMonitor`.
- **Retina Brand Assets**: Universal 1024x1024 AppIcon and 2732x2732 Launch Screens matching CallVexa branding.

---

## 🛠 Project Structure

```
CallVexa/
├── capacitor.config.json           # Remote URL and Capacitor settings
├── codemagic.yaml                  # Cloud Mac CI/CD configuration for .ipa compilation
├── package.json                    # Project dependencies and sync scripts
├── www/                            # Local bundled assets & offline fallback
│   ├── favicon.svg                 # CallVexa brand icon
│   ├── index.html                  # Branded offline fallback shell with auto-reconnect
│   └── offline.html                # Offline error screen
└── ios/App/
    ├── App/
    │   ├── AppDelegate.swift       # Push notifications & audio session setup
    │   ├── MainViewController.swift# WebRTC permissions, offline recovery, link routing
    │   ├── CallKitManager.swift    # Native CallKit provider & call delegate
    │   ├── SceneDelegate.swift     # Window & UI lifecycle
    │   ├── Info.plist              # Microphone, Camera, Photo, VoIP permissions
    │   ├── App.entitlements        # Push notification environment
    │   ├── Assets.xcassets/        # AppIcon (1024x1024) & LaunchScreen (2732x2732)
    │   └── Base.lproj/
    │       ├── LaunchScreen.storyboard
    │       └── Main.storyboard
    ├── ExportOptions-AdHoc.plist   # Codemagic Ad Hoc export configuration
    ├── ExportOptions-Dev.plist     # Codemagic Development export fallback
    └── App.xcodeproj/              # Xcode project configured with all source references
```

---

## 🚀 Building the .ipa on Codemagic

Because building an iOS `.ipa` binary requires a macOS environment with Xcode, Codemagic builds the project on a cloud Mac (macOS M2 runner):

### Step 1: Push Code to Git
Initialize or push this project to your GitHub, GitLab, or Bitbucket repository:
```bash
git add .
git commit -m "Complete CallVexa iOS App setup with CallKit and remote URL wrapper"
git remote add origin <YOUR_GIT_REPO_URL>
git push -u origin main
```

### Step 2: Connect Repository in Codemagic
1. Log into [Codemagic.io](https://codemagic.io).
2. Click **Add application**, select your Git provider, and choose the repository.
3. Select **iOS App** with `codemagic.yaml` as the build configuration.

### Step 3: Configure Signing Variables
In the Codemagic UI (**Environment variables** or **Code signing** tab):
- **Ad Hoc Signing (Automatic)**:
  - Add `APP_STORE_CONNECT_KEY_IDENTIFIER`, `APP_STORE_CONNECT_ISSUER_ID`, and `APP_STORE_CONNECT_PRIVATE_KEY` under the group `apple_credentials`.
  - Set `DEVELOPMENT_TEAM` to your Apple Developer Team ID (`YOUR_TEAM_ID`).
  - Set `APPLE_ID` to your Apple ID (`YOUR_APPLE_ID`).
- **Ad Hoc Signing (Manual)**:
  - Upload your Ad Hoc Provisioning Profile (`.mobileprovision`) containing your test iPhone UDID(s) and your Distribution Certificate (`.p12`).
  - Codemagic will automatically detect and install them in the build keychain.

### Step 4: Run the Build
1. Click **Start new build** and select the `ios-adhoc-ipa` workflow.
2. Codemagic will:
   - Check out code & install dependencies (`npm ci`)
   - Sync Capacitor (`npx cap sync ios`)
   - Compile Xcode release archive
   - Sign and export the `.ipa` package
3. Once completed, download the **`CallVexa-AdHoc.ipa`** (or `CallVexa.ipa`) directly from the **Artifacts** tab!

---

## 📲 Installing the .ipa on a Test iPhone

### Option A: Ad Hoc Distribution (Self-Hosted on callvexa.us)
1. Add the test iPhone's UDID to your Apple Developer Account under **Devices**.
2. Generate an Ad Hoc Provisioning Profile including that device.
3. Host the `.ipa` alongside a `manifest.plist` on `https://callvexa.us/download/app.ipa`.
4. Users install it directly via Safari with one tap:
   ```html
   <a href="itms-services://?action=download-manifest&url=https://callvexa.us/download/manifest.plist">Install CallVexa App</a>
   ```

### Option B: Sideloading (Immediate testing without developer enrollment delay)
You can immediately install the built `.ipa` on any iPhone using:
- **AltStore** (https://altstore.io)
- **Sideloadly** (https://sideloadly.io)
- **Apple Configurator 2** / Xcode Devices window (if connected to a Mac)

### Option C: Apple TestFlight
To distribute to unlimited internal/external testers with automatic updates:
1. Update `method` in `ExportOptions.plist` from `ad-hoc` to `app-store`.
2. Push build to App Store Connect / TestFlight via Codemagic.
