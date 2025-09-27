This is where the prompt to start the session should be placed after each session. Put the most recent prompt at the top and move the previous one down with TLDR/

Continue development on iCapture project.

**Current Status:**
- Milestone 1: Project Bootstrap + Toolchain Pass - 8/8 tasks completed ✅
- Milestone 2: Camera Preview + Frame Box Overlay - 8/8 tasks completed ✅
- Authentication gate: ✅ Basic mock auth implemented
- Git version control: ✅ Fully configured with quality gates
- Next focus: Begin Milestone 3 - Interval Capture with ROI Occupancy Detection

**Immediate Next Steps:**
1. Complete task 3.1: Implement ROI occupancy detection
2. Complete task 3.2: Add background sampling (1s baseline)
3. Complete task 3.3: Create foreground mask calculation
4. Complete task 3.4: Implement occupancy threshold (τ) learning
5. Complete task 3.5: Add interval timer (5s) for ROI occupied state
6. Complete task 3.6: Implement basic photo capture on interval
7. Complete task 3.7: Add capture feedback (flash/sound)
8. Complete task 3.8: Test interval capture with mock vehicle

**Project Context:**
- Hands-free vehicle photo capture app for iPhone 15 Pro+
- ROI-based trigger system (interval + stop detection)
- All processing on-device, no cloud dependencies
- SwiftUI + AVFoundation architecture
- Authentication gate with mock auth system
- Interactive frame box with drag/resize functionality
- Setup wizard with test shot capability
- Git repository with quality gates and pre-commit hooks

**Key Files:**
- `Docs/granular-plan.md` - Detailed implementation roadmap (Milestone 3 ready)
- `Docs/master-plan.md` - Project specifications
- `Docs/git-workflow.md` - Git development guidelines
- `iCapture/ContentView.swift` - Main UI router (auth gate)
- `iCapture/UI/AuthView.swift` - Authentication interface
- `iCapture/UI/CameraView.swift` - Camera functionality
- `iCapture/Core/AuthManager.swift` - Authentication state management
- `iCapture/Core/CameraManager.swift` - AVFoundation camera control
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
- Repository: 2 commits, clean working tree
- Pre-commit hooks: Active (linting + build validation)
- Branch: main (ready for feature/milestone3)

**Ready to begin Milestone 3: Interval Capture with ROI Occupancy Detection!**

---

**TLDR/Previous Session:**
Completed Milestone 2 with full frame box interaction (drag/resize), visual feedback, persistence, setup wizard, and test shot functionality. Set up comprehensive Git repository with quality gates, pre-commit hooks, and workflow documentation. All code passes linting and builds successfully.