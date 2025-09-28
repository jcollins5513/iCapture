This is where the prompt to start the session should be placed after each session. Put the most recent prompt at the top and move the previous one down with TLDR/

Continue development on iCapture project.

**Current Status:**
- Milestone 1: Project Bootstrap + Toolchain Pass - 8/8 tasks completed ✅
- Milestone 2: Camera Preview + Frame Box Overlay - 8/8 tasks completed ✅
- Milestone 3: Interval Capture with ROI Occupancy - 8/8 tasks completed ✅
- Authentication gate: ✅ Basic mock auth implemented
- Git version control: ✅ Fully configured with quality gates
- ROI occupancy detection: ✅ Implemented with Vision framework
- Interval capture system: ✅ Working with 5s timer and debounce
- Background learning: ✅ 1s baseline sampling with progress UI
- Capture feedback: ✅ Flash, haptic, and sound feedback
- Next focus: Begin Milestone 4 - Stop-Based Capture Working

**Immediate Next Steps:**
1. Complete task 4.1: Implement optical flow calculation
2. Complete task 4.2: Add motion magnitude computation over ROI
3. Complete task 4.3: Create sliding window for motion history (15 frames)
4. Complete task 4.4: Implement median filter for motion stability
5. Complete task 4.5: Add stop detection logic (motion < ε for 0.7s)
6. Complete task 4.6: Integrate stop detection with ROI occupancy
7. Complete task 4.7: Add debounce mechanism (1.2s between shots)
8. Complete task 4.8: Test stop-based capture with real motion

**Project Context:**
- Hands-free vehicle photo capture app for iPhone 15 Pro+
- ROI-based trigger system (interval + stop detection)
- All processing on-device, no cloud dependencies
- SwiftUI + AVFoundation architecture
- Authentication gate with mock auth system
- Interactive frame box with drag/resize functionality
- Setup wizard with test shot capability
- Git repository with quality gates and pre-commit hooks
- ROI occupancy detection with background learning
- Interval capture system with 5s timer and debounce
- Visual, haptic, and audio capture feedback

**Key Files:**
- `Docs/granular-plan.md` - Detailed implementation roadmap (Milestone 4 ready)
- `Docs/master-plan.md` - Project specifications
- `Docs/git-workflow.md` - Git development guidelines
- `iCapture/ContentView.swift` - Main UI router (auth gate)
- `iCapture/UI/AuthView.swift` - Authentication interface
- `iCapture/UI/CameraView.swift` - Camera functionality with ROI status
- `iCapture/Core/AuthManager.swift` - Authentication state management
- `iCapture/Core/CameraManager.swift` - AVFoundation camera control with ROI integration
- `iCapture/Core/ROIDetector.swift` - ROI occupancy detection with Vision framework
- `iCapture/Core/TriggerEngine.swift` - Interval capture system with debounce
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
- Branch: main (ready for feature/milestone4)

**Ready to begin Milestone 4: Stop-Based Capture Working!**

---

**TLDR/Previous Session:**
Completed Milestone 3 with full ROI occupancy detection, background learning, interval capture system, and capture feedback. Implemented Vision framework integration for ROI detection, 5-second interval timer with debounce, visual/haptic/audio feedback, and comprehensive UI integration. All code passes linting and builds successfully. Ready for Milestone 4: Stop-Based Capture Working.