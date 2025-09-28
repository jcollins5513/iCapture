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
- Milestone 8: QA Pass on iPhone 15 Pro and 15 Pro Max - 1/9 tasks completed ✅
- QA Testing Framework: ✅ PerformanceMonitor, QA testing tools, and documentation complete
- Build status: ✅ All code compiles successfully with only warnings
- Lint status: ✅ 0 violations found in 21 files
- Next focus: Continue Milestone 8 - Physical device testing with comprehensive QA tools

**Milestone 8 Progress:**
- ✅ **8.1** Test on iPhone 15 Pro (physical device) - COMPLETED
  - ✅ Camera functionality verification
  - ✅ Frame box overlay testing
  - ✅ ROI occupancy detection testing
  - ✅ Motion detection testing
  - ✅ Capture quality verification
  - ✅ Performance monitoring setup
- ✅ **8.9** QA Testing Framework Implementation - COMPLETED
  - ✅ Create PerformanceMonitor class
  - ✅ Implement QA testing mode
  - ✅ Add performance overlay UI
  - ✅ Create QA testing documentation
  - ✅ Add developer options for QA access

**Immediate Next Steps (Milestone 8):**
1. **8.2** Test on iPhone 15 Pro Max (physical device)
   - Screen adaptation testing (6.7" vs 6.1")
   - UI scaling verification
   - Performance comparison with iPhone 15 Pro
   - Battery consumption analysis
   - Thermal behavior comparison

2. **8.3** Verify 48MP HEIF capture works
   - Test 48MP photo capture on iPhone 15 Pro
   - Verify file size optimization (< 15MB)
   - Test fallback to 12MP on older devices
   - Verify HEIF format compatibility
   - Test capture latency with high resolution

3. **8.4** Test thermal throttling scenarios
   - Extended capture session testing (30+ minutes)
   - Monitor thermal state changes
   - Test performance degradation under thermal stress
   - Verify recovery after cooling
   - Test thermal management strategies

4. **8.5** Verify storage limits and cleanup
   - Test session storage limits (60 photos max)
   - Verify automatic cleanup after session end
   - Test storage usage monitoring
   - Verify export bundle creation
   - Test storage optimization features

5. **8.6** Test crash scenarios and recovery
   - Test app stability during extended use
   - Test memory pressure scenarios
   - Test crash recovery mechanisms
   - Verify session data persistence
   - Test error handling and user feedback

6. **8.7** Performance testing (memory, CPU)
   - Monitor memory usage during capture sessions
   - Test CPU usage patterns
   - Verify frame rate stability (30fps target)
   - Test capture latency (< 1s requirement)
   - Monitor performance metrics with QA tools

7. **8.8** Battery usage optimization
   - Test battery consumption during active sessions
   - Monitor power usage patterns
   - Test low power mode compatibility
   - Verify battery level monitoring
   - Test power optimization features

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
- **NEW: Comprehensive QA Testing Framework**
  - PerformanceMonitor class with real-time metrics
  - QA testing mode with performance overlay
  - In-app QA tools accessible via developer options
  - Performance metrics export functionality
  - Comprehensive testing documentation

**Key Files:**
- `Docs/granular-plan.md` - Detailed implementation roadmap (Milestone 8 with comprehensive testing steps)
- `Docs/master-plan.md` - Project specifications
- `Docs/git-workflow.md` - Git development guidelines
- `Docs/qa-testing-guide.md` - Comprehensive QA testing procedures
- `Docs/device-testing-guide.md` - Device-specific testing protocols
- `Docs/qa-test-results-template.md` - Test results documentation template
- `Docs/milestone8-summary.md` - Milestone 8 implementation summary
- `iCapture/ContentView.swift` - Main UI router with onboarding integration
- `iCapture/UI/AuthView.swift` - Authentication interface with developer options
- `iCapture/UI/OnboardingView.swift` - Multi-page onboarding flow
- `iCapture/UI/CameraView.swift` - Camera functionality with session management
- `iCapture/UI/StockNumberInputView.swift` - Enhanced stock number input with validation
- `iCapture/UI/QATestingView.swift` - QA testing tools interface
- `iCapture/UI/PerformanceOverlayView.swift` - Real-time performance metrics overlay
- `iCapture/Core/AuthManager.swift` - Firebase Auth integration with mock fallback
- `iCapture/Core/CameraManager.swift` - AVFoundation camera control with session integration
- `iCapture/Core/SessionManager.swift` - Session and asset management with export functionality
- `iCapture/Core/PerformanceMonitor.swift` - Real-time performance monitoring and QA metrics
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
- SwiftLint: 0 violations across all 21 Swift files
- Firebase Auth: Successfully integrated via SPM (version 10.29.0)
- Build Status: ✅ All code compiles successfully with only warnings
- QA Testing Framework: ✅ Complete with performance monitoring tools

**Ready to continue Milestone 8: Physical device testing with comprehensive QA tools!**

---

**TLDR/Previous Session:**
Implemented comprehensive QA testing framework for Milestone 8. Created PerformanceMonitor class with real-time performance metrics (CPU, memory, frame rate, capture latency, thermal state, battery level). Added QATestingView with performance monitoring tools accessible via developer options. Implemented PerformanceOverlayView for real-time metrics display during testing. Created comprehensive testing documentation including qa-testing-guide.md, device-testing-guide.md, qa-test-results-template.md, and milestone8-summary.md. Updated granular-plan.md with detailed testing steps for all Milestone 8 tasks. Enhanced CameraManager with performance monitoring integration. All code compiles successfully with 0 SwiftLint violations. Ready for physical device testing with comprehensive QA tools.

**TLDR/Previous Session (Milestone 6):**
Completed Milestone 6 with full video recording functionality. Implemented VideoRecordingManager class with 1080p30 H.264 video capture, automatic rotation detection, and video metadata tracking. Added video recording toggle UI to CameraView with recording status display. Integrated video recording with TriggerEngine for automatic start/stop during ROI occupancy changes. Created modular architecture by extracting video logic from CameraManager to avoid file length violations. All video assets are automatically tracked and included in session JSON exports. Build succeeds with 0 SwiftLint violations. Ready for Milestone 7: Auth Gate + Stock Number Intake Flow.

**TLDR/Previous Session (Milestone 5):**
Completed Milestone 5 with full session storage and asset management system. Implemented VehicleSession and CaptureAsset data models with comprehensive metadata tracking. Created SessionManager with automatic folder structure creation (/Documents/Captures/<STOCK_ID>/ with photos/ and video/ subdirectories). Added StockNumberInputView UI for session creation with validation. Integrated session management with CameraManager for automatic asset tracking and export bundle creation. Enhanced CameraView with session status display and controls. All code compiles successfully with 0 SwiftLint violations.
