# iCapture

Hands-free, statically mounted iPhone app for capturing vehicle photos during rotation.

## Quick Start

- **Build**: `./Scripts/Scripts:build.sh`
- **Lint**: `./Scripts/Scripts:lint.sh`
- **Pre-commit**: `./Scripts/Scripts:precommit.sh`
- **Run**: Open in Xcode and select a physical iPhone 15 Pro/Pro Max

## Project Structure

```
iCapture/
├── iCapture/                 # Main app source code
│   ├── Assets.xcassets/      # App icons and assets
│   ├── Config/              # Configuration files
│   │   └── .swiftlint.yml   # SwiftLint configuration
│   ├── ContentView.swift    # Main UI view
│   └── iCaptureApp.swift    # App entry point
├── Scripts/                 # Build and development scripts
│   ├── Scripts:build.sh    # Build script
│   ├── Scripts:lint.sh     # Lint script
│   └── Scripts:precommit.sh # Pre-commit validation
├── Docs/                   # Project documentation
│   ├── master-plan.md      # High-level project plan
│   └── granular-plan.md    # Detailed implementation tasks
└── README.md               # This file
```

## Requirements

- iOS 26.0+
- iPhone 15 Pro and newer
- Xcode 26.0+
- SwiftLint (install via Homebrew: `brew install swiftlint`)

## Development Workflow

1. **Respect project rules**: Follow `Docs/master-plan.md` and `Docs/granular-plan.md`
2. **Never change scope**: Do not modify master-plan.md except to check off approvals
3. **Keep it simple**: ROI occupancy + interval/stop triggers only
4. **No cloud calls**: Everything remains on-device
5. **Update granular plan**: Check off completed tasks at end of session

## Current Status

- ✅ Project bootstrap + toolchain pass (build, lint, run)
- ✅ Info.plist permissions added (camera, microphone)
- ✅ iOS deployment target set to 26.0
- ✅ Device family restricted to iPhone only
- ⏳ Next: Test on iPhone 15 Pro simulator, then begin camera preview

## Architecture

- **UI Layer**: SwiftUI with full-screen preview and frame box overlay
- **Capture Core**: AVFoundation pipeline (HEIF 48MP stills, 1080p H.264 video)
- **Trigger Engine**: Vision + optical flow + motion heuristic
- **ROI Detector**: User-defined rectangle with occupancy detection
- **Session Manager**: Creates organized folders with metadata JSON
- **Auth**: Firebase Auth for sign-in gating only
- **Storage**: Local SQLite/JSON with export bundles

## Key Features

- Hands-free vehicle photo capture
- ROI-based trigger system (interval + stop detection)
- Stock number organization
- Local storage and export
- iPhone 15 Pro+ optimization
- On-device processing only

## Next Steps

See `Docs/granular-plan.md` for detailed implementation tasks. Current focus: Milestone 1 completion.
