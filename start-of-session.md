# iCapture – Next Session Prompt

## Project Status
Hands-free iPhone capture app focused on subject lifting quality for dealership-ready exports.

**Current Focus**: Subject-lift polish and depth boost UX — Milestone 8 follow-up work in progress (~80% complete).

## Recent Accomplishments ✅
- Defaulted to Vision-only background removal after each capture; LiDAR now an optional "Depth Boost" with clear status chips.
- Added refined mask processing (morphological close + blur) to tighten subject edges compared to iOS sticker baseline.
- Prevented automatic Photo Library saves to keep all assets in `/Documents/Captures/<session>` for in-app access.
- Simplified detection controls and status HUD to highlight background learning + depth readiness states.

## Active Issues / Observations ⚠️
- Session export still logs `Code=260` copy failures because assets may not exist when export runs (needs retry/await).
- Captures remain 12 MP due to Apple's pipeline limits; ProRAW/HEIF Max experiment still pending.
- No built-in gallery yet—need an in-app browser to review cutouts/stickers without jumping to Photos.

## Next Priority Tasks
1. **Session Assets Reliability**
   - Wait-for-write or retry loop before export copies (`SessionManager`).
   - Add logging when asset write finishes vs. export start.
2. **Mask Quality Validation**
   - Compare new Vision-only edges vs. iOS sticker output on a small test set.
   - Tune feather/blur radii and consider bilateral refinement pass.
3. **In-App Gallery / Media Browser**
   - Surface session photos/cutouts/stickers locally (no Photos dependency).
   - Optional share/export actions and delete safeguards.
4. **Depth Boost UX Polish**
   - Persist most recent depth map timestamp; auto-expire after N minutes.
   - Evaluate energy impact and consider throttle/cooldown telemetry.
5. **High-Resolution Capture Follow-up (Deferred)**
   - Prototype single ProRAW capture to confirm 48 MP path before reintroducing.

## Key Files Updated This Session
- `iCapture/Core/CameraManager.swift`, `CameraManager+BackgroundRemoval.swift`
- `iCapture/Core/BackgroundRemover.swift`
- `iCapture/UI/CameraView.swift`

## Build / Lint
- ✅ `xcodebuild -scheme iCapture -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- ⚠️ `swiftlint` still reports legacy length violations (no new ones introduced).

## Next Session Kickoff
Focus on stabilising session asset persistence and delivering an in-app gallery while validating the new Vision-only mask quality. Depth boost experiments and any ProRAW checks can follow once export reliability is solved.
