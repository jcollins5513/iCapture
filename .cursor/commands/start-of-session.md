This is where the prompt to start the session should be placed after each session. Put the most recent prompt at the top and move the previous one down with TLDR/

Continue development on iCapture project.

**Current Status:**
- Milestone 1: Project Bootstrap + Toolchain Pass - 8/8 tasks completed ✅
- Milestone 2: Camera Preview + Frame Box Overlay - 8/8 tasks completed ✅
- Milestone 3: Interval Capture with ROI Occupancy - 8/8 tasks completed ✅
- Milestone 4: Stop-Based Capture Working - 8/8 tasks completed ✅
- Milestone 5: Session Storage + Per-Stock Folders + JSON Export - 10/10 tasks completed ✅
- Milestone 6: Video Recording Toggle During Rotation - 7/7 tasks completed ✅
- Milestone 7: Auth Gate + Stock Number Intake Flow - 8/8 tasks completed ✅
- Authentication gate: ✅ Firebase Auth dependency added with mock auth fallback
- Git version control: ✅ Fully configured with quality gates
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
- Code quality: ✅ All SwiftLint violations resolved (0 violations)
- Build status: ✅ All code compiles successfully with only warnings
- Next focus: Begin Milestone 8 - QA Pass on iPhone 15 Pro and 15 Pro Max

**Immediate Next Steps:**
1. Complete task 8.1: Test on iPhone 15 Pro (physical device)
2. Complete task 8.2: Test on iPhone 15 Pro Max (physical device)
3. Complete task 8.3: Verify 48MP HEIF capture works
4. Complete task 8.4: Test thermal throttling scenarios
5. Complete task 8.5: Verify storage limits and cleanup
6. Complete task 8.6: Test crash scenarios and recovery
7. Complete task 8.7: Performance testing (memory, CPU)
8. Complete task 8.8: Battery usage optimization

**Project Context:**
- Hands-free vehicle photo capture app for iPhone 15 Pro+
- ROI-based trigger system (interval + stop detection)
- All processing on-device, no cloud dependencies
- SwiftUI + AVFoundation architecture
- Complete authentication and onboarding system
- Firebase Auth integration ready for production
- Interactive frame box with drag/resize functionality
- Multi-page onboarding flow with frame box setup
- Enhanced stock number validation with real-time feedback
- Developer options for testing and reset functionality
- Git repository with quality gates and pre-commit hooks
- ROI occupancy detection with background learning
- Interval capture system with 5s timer and debounce
- Visual, haptic, and audio capture feedback
- Motion detection with optical flow and stop detection
- Complete stop-based capture system with debounce

**Key Files:**
- `Docs/granular-plan.md` - Detailed implementation roadmap (Milestone 8 ready)
- `Docs/master-plan.md` - Project specifications
- `Docs/git-workflow.md` - Git development guidelines
- `iCapture/ContentView.swift` - Main UI router with onboarding integration
- `iCapture/UI/AuthView.swift` - Authentication interface with developer options
- `iCapture/UI/OnboardingView.swift` - Multi-page onboarding flow
- `iCapture/UI/CameraView.swift` - Camera functionality with session management
- `iCapture/UI/StockNumberInputView.swift` - Enhanced stock number input with validation
- `iCapture/Core/AuthManager.swift` - Firebase Auth integration with mock fallback
- `iCapture/Core/CameraManager.swift` - AVFoundation camera control with session integration
- `iCapture/Core/SessionManager.swift` - Session and asset management with export functionality
- `iCapture/Core/VehicleSession.swift` - Session data model with metadata
- `iCapture/Core/CaptureAsset.swift` - Asset data model with file management
- `iCapture/Core/ROIDetector.swift` - ROI occupancy detection with Vision framework
- `iCapture/Core/MotionDetector.swift` - Optical flow calculation and stop detection
- `iCapture/Core/TriggerEngine.swift` - Interval + stop-based capture system
- `iCapture/UI/FrameBoxOverlay.swift` - ROI selection component (fully interactive)
- `iCapture/UI/FrameBoxSetupWizard.swift` - Setup wizard with test shots

**Development Rules:**
- Respect master-plan.md as single source of truth
- Keep trigger logic simple: ROI occupancy + interval/stop
- Never add cloud calls, everything on-device
- Update granular-plan.md by checking off completed tasks
- Run `./Scripts/Scripts:precommit.sh` before commits
- Use Git workflow: feature branches, quality gates, standardized commits

**Demo Credentials:**
- admin / password123 (Administrator)
- demo / demo123 (Demo User)
- test / test123 (Test User)

**Git Status:**
- Repository: Clean working tree, all linting issues resolved
- Pre-commit hooks: Active (linting + build validation)
- Branch: main (ready for feature/milestone8)
- SwiftLint: 0 violations across all 18 Swift files
- Firebase Auth: Successfully integrated via SPM (version 10.29.0)

**Ready to begin Milestone 8: QA Pass on iPhone 15 Pro and 15 Pro Max!**

---

**TLDR/Previous Session:**
Completed Milestone 7 with comprehensive authentication and onboarding system. Added Firebase Auth dependency via SPM with mock auth fallback for development. Enhanced stock number validation with real-time feedback, visual indicators, and comprehensive validation rules. Created multi-page onboarding flow with beautiful transitions and frame box setup integration. Implemented OnboardingManager for state persistence and developer options for testing. Updated AuthManager with Firebase Auth integration ready for production. All authentication flows tested and working perfectly. Build succeeds with 0 SwiftLint violations. Ready for Milestone 8: QA Pass on iPhone 15 Pro and 15 Pro Max.

**TLDR/Previous Session (Milestone 6):**
Completed Milestone 6 with full video recording functionality. Implemented VideoRecordingManager class with 1080p30 H.264 video capture, automatic rotation detection, and video metadata tracking. Added video recording toggle UI to CameraView with recording status display. Integrated video recording with TriggerEngine for automatic start/stop during ROI occupancy changes. Created modular architecture by extracting video logic from CameraManager to avoid file length violations. All video assets are automatically tracked and included in session JSON exports. Build succeeds with 0 SwiftLint violations. Ready for Milestone 7: Auth Gate + Stock Number Intake Flow.

**TLDR/Previous Session (Milestone 5):**
Completed Milestone 5 with full session storage and asset management system. Implemented VehicleSession and CaptureAsset data models with comprehensive metadata tracking. Created SessionManager with automatic folder structure creation (/Documents/Captures/<STOCK_ID>/ with photos/ and video/ subdirectories). Added StockNumberInputView UI for session creation with validation. Integrated session management with CameraManager for automatic asset tracking and export bundle creation. Enhanced CameraView with session status display and controls. All code compiles successfully with 0 SwiftLint violations.
