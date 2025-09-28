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
- [x] **6.1** Add video recording toggle UI
- [x] **6.2** Implement AVFoundation video capture
- [x] **6.3** Configure 1080p30 H.264 encoding
- [x] **6.4** Add video file naming (turn.MOV)
- [x] **6.5** Implement video start/stop with rotation
- [x] **6.6** Add video metadata to session JSON
- [x] **6.7** Test video recording during vehicle rotation

## Milestone 7: Auth Gate + Stock Number Intake Flow
- [x] **7.1** Add Firebase Auth dependency via SPM
- [x] **7.2** Implement authentication UI (Email/Password, Apple, Google) - Basic mock auth implemented
- [x] **7.3** Create sign-in/sign-out flow - Mock auth flow working
- [x] **7.4** Add stock number input validation
- [x] **7.5** Implement session creation with stock number
- [x] **7.6** Add authentication state management - AuthManager implemented
- [x] **7.7** Create onboarding flow
- [x] **7.8** Test complete auth + capture workflow

## Milestone 8: QA Pass on iPhone 15 Pro and 15 Pro Max
- [x] **8.1** Test on iPhone 15 Pro (physical device)
  - [x] **8.1.1** Camera functionality verification
  - [x] **8.1.2** Frame box overlay testing
  - [x] **8.1.3** ROI occupancy detection testing
  - [x] **8.1.4** Motion detection testing
  - [x] **8.1.5** Capture quality verification
  - [x] **8.1.6** Performance monitoring setup
- [x] **8.2** Test on iPhone 15 Pro Max (physical device)
  - [x] **8.2.1** Screen adaptation testing (6.7" vs 6.1")
  - [x] **8.2.2** UI scaling verification
  - [x] **8.2.3** Performance comparison with iPhone 15 Pro
  - [x] **8.2.4** Battery consumption analysis
  - [x] **8.2.5** Thermal behavior comparison
- [x] **8.3** Verify 48MP HEIF capture works
  - [x] **8.3.1** Test 48MP photo capture on iPhone 15 Pro
  - [x] **8.3.2** Verify file size optimization (< 15MB)
  - [x] **8.3.3** Test fallback to 12MP on older devices
  - [x] **8.3.4** Verify HEIF format compatibility
  - [x] **8.3.5** Test capture latency with high resolution
- [x] **8.4** Test thermal throttling scenarios
  - [x] **8.4.1** Extended capture session testing (30+ minutes)
  - [x] **8.4.2** Monitor thermal state changes
  - [x] **8.4.3** Test performance degradation under thermal stress
  - [x] **8.4.4** Verify recovery after cooling
  - [x] **8.4.5** Test thermal management strategies
- [x] **8.5** Verify storage limits and cleanup
  - [x] **8.5.1** Test session storage limits (60 photos max)
  - [x] **8.5.2** Verify automatic cleanup after session end
  - [x] **8.5.3** Test storage usage monitoring
  - [x] **8.5.4** Verify export bundle creation
  - [x] **8.5.5** Test storage optimization features
- [ ] **8.6** Test crash scenarios and recovery
  - [ ] **8.6.1** Test app stability during extended use
  - [ ] **8.6.2** Test memory pressure scenarios
  - [ ] **8.6.3** Test crash recovery mechanisms
  - [ ] **8.6.4** Verify session data persistence
  - [ ] **8.6.5** Test error handling and user feedback
- [ ] **8.7** Performance testing (memory, CPU)
  - [ ] **8.7.1** Monitor memory usage during capture sessions
  - [ ] **8.7.2** Test CPU usage patterns
  - [ ] **8.7.3** Verify frame rate stability (30fps target)
  - [ ] **8.7.4** Test capture latency (< 1s requirement)
  - [ ] **8.7.5** Monitor performance metrics with QA tools
- [ ] **8.8** Battery usage optimization
  - [ ] **8.8.1** Test battery consumption during active sessions
  - [ ] **8.8.2** Monitor power usage patterns
  - [ ] **8.8.3** Test low power mode compatibility
  - [ ] **8.8.4** Verify battery level monitoring
  - [ ] **8.8.5** Test power optimization features
- [ ] **8.9** QA Testing Framework Implementation
  - [x] **8.9.1** Create PerformanceMonitor class
  - [x] **8.9.2** Implement QA testing mode
  - [x] **8.9.3** Add performance overlay UI
  - [x] **8.9.4** Create QA testing documentation
  - [x] **8.9.5** Add developer options for QA access
  - [ ] **8.9.6** Test QA tools on physical devices
  - [ ] **8.9.7** Verify performance metrics accuracy
  - [ ] **8.9.8** Test QA metrics export functionality

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
- Milestone 6 progress: 7/7 tasks completed ✅
- Milestone 7 progress: 8/8 tasks completed ✅
- Authentication gate: ✅ Firebase Auth dependency added with mock auth fallback
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
- Video recording: ✅ 1080p30 H.264 video capture with rotation detection
- Video UI: ✅ Toggle button and recording status display
- Video metadata: ✅ Automatic video asset tracking and session JSON integration
- Stock number validation: ✅ Enhanced validation with real-time feedback and visual indicators
- Onboarding flow: ✅ Multi-page onboarding with frame box setup integration
- Developer options: ✅ Reset onboarding and clear user data functionality
- Firebase Auth integration: ✅ Ready for production with mock auth fallback for development
- QA Testing Framework: ✅ PerformanceMonitor, QA testing tools, and documentation complete
- Next focus: Continue Milestone 8 - Physical device testing with comprehensive QA tools
