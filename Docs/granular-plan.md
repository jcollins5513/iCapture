# iCapture Granular Plan

Based on master-plan.md. Update by checking off completed tasks.

## Milestone 1: Project Bootstrap + Toolchain Pass
- [x] **1.1** Verify Xcode project builds successfully
- [x] **1.2** Install and configure SwiftLint
- [x] **1.3** Run lint script and fix any violations
- [x] **1.4** Verify build script works
- [x] **1.5** Test app runs on iPhone 15 Pro simulator
- [x] **1.6** Add required Info.plist permissions (camera, microphone)
- [x] **1.7** Set up proper iOS deployment target (26.0)
- [x] **1.8** Configure device family restrictions (iPhone only)

## Milestone 2: Camera Preview + Frame Box Overlay
- [x] **2.1** Create CameraPreviewView with AVFoundation
- [x] **2.2** Implement full-screen camera preview
- [x] **2.3** Add frame box overlay UI component
- [x] **2.4** Make frame box draggable/resizable
- [x] **2.5** Add visual feedback for frame box interaction
- [x] **2.6** Implement frame box persistence (UserDefaults)
- [x] **2.7** Add setup wizard for frame box positioning
- [x] **2.8** Create test shot functionality

## Milestone 3: Interval Capture with ROI Occupancy
- [x] **3.1** Implement ROI occupancy detection
- [x] **3.2** Add background sampling (1s baseline)
- [x] **3.3** Create foreground mask calculation
- [x] **3.4** Implement occupancy threshold (τ) learning
- [x] **3.5** Add interval timer (5s) for ROI occupied state
- [x] **3.6** Implement basic photo capture on interval
- [x] **3.7** Add capture feedback (flash/sound)
- [x] **3.8** Test interval capture with mock vehicle

## Milestone 4: Stop-Based Capture Working
- [x] **4.1** Implement optical flow calculation
- [x] **4.2** Add motion magnitude computation over ROI
- [x] **4.3** Create sliding window for motion history (15 frames)
- [x] **4.4** Implement median filter for motion stability
- [x] **4.5** Add stop detection logic (motion < ε for 0.7s)
- [x] **4.6** Integrate stop detection with ROI occupancy
- [x] **4.7** Add debounce mechanism (1.2s between shots)
- [x] **4.8** Test stop-based capture with real motion

## Milestone 5: Session Storage + Per-Stock Folders + JSON Export
- [x] **5.1** Create VehicleSession data model
- [x] **5.2** Create CaptureAsset data model
- [x] **5.3** Implement session manager
- [x] **5.4** Create /Documents/Captures/<STOCK_ID>/ folder structure
- [x] **5.5** Add photos/ and video/ subdirectories
- [x] **5.6** Implement session.json creation
- [x] **5.7** Add asset metadata to JSON
- [x] **5.8** Create export bundle functionality
- [x] **5.9** Add stock number input UI
- [x] **5.10** Implement session start/end workflow

## Milestone 6: Video Recording Toggle During Rotation
- [ ] **6.1** Add video recording toggle UI
- [ ] **6.2** Implement AVFoundation video capture
- [ ] **6.3** Configure 1080p30 H.264 encoding
- [ ] **6.4** Add video file naming (turn.MOV)
- [ ] **6.5** Implement video start/stop with rotation
- [ ] **6.6** Add video metadata to session JSON
- [ ] **6.7** Test video recording during vehicle rotation

## Milestone 7: Auth Gate + Stock Number Intake Flow
- [ ] **7.1** Add Firebase Auth dependency via SPM
- [x] **7.2** Implement authentication UI (Email/Password, Apple, Google) - Basic mock auth implemented
- [x] **7.3** Create sign-in/sign-out flow - Mock auth flow working
- [ ] **7.4** Add stock number input validation
- [ ] **7.5** Implement session creation with stock number
- [x] **7.6** Add authentication state management - AuthManager implemented
- [ ] **7.7** Create onboarding flow
- [ ] **7.8** Test complete auth + capture workflow

## Milestone 8: QA Pass on iPhone 15 Pro and 15 Pro Max
- [ ] **8.1** Test on iPhone 15 Pro (physical device)
- [ ] **8.2** Test on iPhone 15 Pro Max (physical device)
- [ ] **8.3** Verify 48MP HEIF capture works
- [ ] **8.4** Test thermal throttling scenarios
- [ ] **8.5** Verify storage limits and cleanup
- [ ] **8.6** Test crash scenarios and recovery
- [ ] **8.7** Performance testing (memory, CPU)
- [ ] **8.8** Battery usage optimization

## Milestone 9: Pre-Release Field Test in Booth
- [ ] **9.1** Create field test checklist
- [ ] **9.2** Test with various vehicle types
- [ ] **9.3** Test in different lighting conditions
- [ ] **9.4** Verify mounting stability
- [ ] **9.5** Test complete session workflows
- [ ] **9.6** Gather user feedback
- [ ] **9.7** Document issues and fixes
- [ ] **9.8** Final performance validation

## Technical Implementation Details

### Core Components to Create
- [ ] **CameraManager**: AVFoundation camera control
- [ ] **ROIDetector**: Region of interest occupancy detection
- [ ] **MotionDetector**: Optical flow and motion analysis
- [ ] **TriggerEngine**: Interval and stop-based triggers
- [ ] **SessionManager**: Session and asset management
- [ ] **AuthManager**: Firebase authentication
- [ ] **StorageManager**: File system operations

### UI Components to Create
- [ ] **CameraPreviewView**: Full-screen camera display
- [ ] **FrameBoxOverlay**: Draggable ROI rectangle
- [ ] **CaptureHUD**: Session status and controls
- [ ] **AuthView**: Authentication interface
- [ ] **SessionSetupView**: Stock number and configuration
- [ ] **SettingsView**: App configuration

### Data Models to Create
- [ ] **VehicleSession**: Session metadata
- [ ] **CaptureAsset**: Individual photo/video metadata
- [ ] **SessionJSON**: Export format
- [ ] **ROIConfig**: Frame box configuration
- [ ] **TriggerConfig**: Motion detection parameters

## Current Status
- Project structure: ✅ Complete
- Master plan: ✅ Complete
- Granular plan: ✅ Complete
- Milestone 1 progress: 8/8 tasks completed ✅
- Milestone 2 progress: 8/8 tasks completed ✅
- Milestone 3 progress: 8/8 tasks completed ✅
- Milestone 4 progress: 8/8 tasks completed ✅
- Milestone 5 progress: 10/10 tasks completed ✅
- Authentication gate: ✅ Basic mock auth implemented
- ROI occupancy detection: ✅ Implemented with Vision framework
- Interval capture system: ✅ Working with 5s timer and debounce
- Background learning: ✅ 1s baseline sampling with progress UI
- Capture feedback: ✅ Flash, haptic, and sound feedback
- Motion detection: ✅ Optical flow calculation with stop detection
- Stop-based capture: ✅ Integrated with ROI occupancy and debounce
- Session management: ✅ Complete session storage with per-stock folders and JSON export
- Stock number input: ✅ UI for starting new sessions with stock number validation
- Asset tracking: ✅ CaptureAsset model with metadata and file management
- Export functionality: ✅ Automatic export bundle creation with organized assets
- Next focus: Begin Milestone 6 - Video Recording Toggle During Rotation
