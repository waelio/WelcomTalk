# WelcomTalk — Agent Instructions

This repo is a SwiftUI iOS app with MVVM + Combine and a pure Swift shared library. Use `README.md` for product intent and feature context, and use this file for implementation guidance.

## Build & Test

- Open in Xcode: `open WelcomTalk.xcodeproj`
- Build simulator: `xcodebuild build -scheme WelcomTalk -destination 'platform=iOS Simulator,name=iPhone 16'`
- Build device: `xcodebuild build -scheme WelcomTalk -destination 'generic/platform=iOS'`
- Unit tests: `swift test`
- UI tests: `xcodebuild test -scheme WelcomTalk -destination 'platform=iOS Simulator,name=iPhone 16'`

## Architecture

- SwiftUI + MVVM + Combine
- `Views/` contains UI
- `ViewModels/` contains app state, business logic, and session coordination
- `Services/` contains platform integration and external APIs
- `WelcomShared` is a pure Swift package; avoid UIKit/AppKit imports there
- `SessionViewModel.swift` is the main session state coordinator
- Host drives the countdown timer and broadcasts `SessionSyncMessage`; guests consume sync updates only

## Key service boundaries

- `Services/MultipeerService.swift` — Peer-to-peer sync (Bonjour: `welcomtalk`)
- `Services/WebSocketService.swift` — Optional server-backed sync
- `Services/SessionMessagingService.swift` — Shared session wire protocol
- `Services/SpeechRecognitionService.swift`
- `Services/NFCSessionManager.swift`
- `QRCodeGenerator.swift`, `QRCodeScanner.swift`
- `Utils/ShareSheet.swift`

## Important conventions for agents

- Keep UI work inside SwiftUI views and avoid UIKit unless absolutely necessary
- Use `Services/` for integration code, not for core session/business logic
- Keep shared models and `WelcomShared` code platform-agnostic
- Preserve the observed `ViewModel → Service` pattern:
  - private service properties in view models
  - Combine publishers/sinks for service updates
  - imperative service calls from the view model
- Prefer localized changes over broad refactors unless the feature requires it
- Update tests for any behavior changes

## Testing details

- `WelcomSharedTests` is for pure logic and shared models
- `swift test` is the correct fast path for library-level tests
- `WelcomTalkUITests` is for UI behavior and device-like flows
- UI tests launch with `app.launchArguments = ["UI_TESTING"]`
- `AppStoreScreenshotTests` writes screenshots to `/tmp/screenshots/`

## Project-specific notes

- `WebSocketService` defaults:
  - Simulator: `ws://localhost:8080`
  - Device: `wss://waelio-messaging.onrender.com`
- `WelcomShared` should remain import-safe for cross-platform use
- This project is evolving toward a broader debate protocol abstraction, so prefer small
  session/service abstractions over large UI rewrites.
- `fastlane capture` depends on `/tmp/take_screenshots.sh` (not committed)

## References

- Product and feature details: `README.md`
- Deep-link behavior: `/memories/repo/deep-links.md`
