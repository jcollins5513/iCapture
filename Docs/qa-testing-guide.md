# iCapture QA Testing Guide

## Milestone 8: QA Pass on iPhone 15 Pro and 15 Pro Max

### Prerequisites
- iPhone 15 Pro or iPhone 15 Pro Max (physical device)
- Xcode 26.0+ with iOS 26.0 deployment target
- Test environment with good lighting
- Test vehicle or object for capture testing
- Mounting solution for iPhone

### Test Environment Setup
1. **Device Preparation**
   - Ensure device is running iOS 26.0+
   - Clear device storage (minimum 10GB free)
   - Disable Low Power Mode
   - Enable Developer Mode if needed
   - Set screen brightness to 50% for consistent testing

2. **App Installation**
   - Build and install from Xcode
   - Grant camera permissions
   - Complete onboarding flow
   - Configure frame box for test area

### Test Cases

#### 8.1 & 8.2: Device Testing (iPhone 15 Pro & Pro Max)

**Camera Functionality Tests**
- [ ] Camera preview displays correctly
- [ ] Frame box overlay is visible and interactive
- [ ] Background sampling works (1s baseline)
- [ ] ROI occupancy detection responds to objects
- [ ] Motion detection works with moving objects
- [ ] Stop detection triggers on stationary objects

**Capture Quality Tests**
- [ ] Photos capture at 48MP HEIF when available
- [ ] Fallback to 12MP works on older devices
- [ ] Video recording at 1080p30 H.264
- [ ] Capture feedback (flash, haptic, sound) works
- [ ] File sizes are reasonable (48MP < 15MB, 12MP < 5MB)

**Performance Tests**
- [ ] App launches in < 3 seconds
- [ ] Camera starts in < 2 seconds
- [ ] Capture latency < 1 second from trigger
- [ ] Memory usage < 500MB during active session
- [ ] CPU usage < 80% during capture

#### 8.3: 48MP HEIF Capture Verification

**High-Resolution Testing**
- [ ] Verify 48MP capture on iPhone 15 Pro
- [ ] Verify 48MP capture on iPhone 15 Pro Max
- [ ] Check file format is HEIF
- [ ] Verify image quality and sharpness
- [ ] Test file size optimization
- [ ] Verify metadata embedding

**Quality Assurance**
- [ ] Test in various lighting conditions
- [ ] Verify focus accuracy
- [ ] Check for motion blur
- [ ] Test with different vehicle sizes
- [ ] Verify color accuracy

#### 8.4: Thermal Throttling Scenarios

**Extended Use Testing**
- [ ] Run continuous capture for 30 minutes
- [ ] Monitor device temperature
- [ ] Check for performance degradation
- [ ] Verify capture quality under thermal stress
- [ ] Test recovery after cooling

**Thermal Management**
- [ ] Monitor CPU throttling
- [ ] Check for frame rate drops
- [ ] Verify capture continues during throttling
- [ ] Test thermal warnings handling

#### 8.5: Storage Limits and Cleanup

**Storage Management**
- [ ] Test session limit (60 photos max)
- [ ] Verify automatic cleanup
- [ ] Test storage full scenarios
- [ ] Check export bundle creation
- [ ] Verify file organization

**Session Management**
- [ ] Test multiple sessions
- [ ] Verify session isolation
- [ ] Check storage usage reporting
- [ ] Test cleanup on session end

#### 8.6: Crash Scenarios and Recovery

**Stability Testing**
- [ ] Test app recovery after backgrounding
- [ ] Test session recovery after crash
- [ ] Verify data persistence
- [ ] Test memory pressure scenarios
- [ ] Check error handling

**Recovery Mechanisms**
- [ ] Test session resumption
- [ ] Verify asset recovery
- [ ] Check state restoration
- [ ] Test graceful degradation

#### 8.7: Performance Testing (Memory, CPU)

**Resource Monitoring**
- [ ] Monitor memory usage patterns
- [ ] Check for memory leaks
- [ ] Monitor CPU usage during capture
- [ ] Test background processing
- [ ] Verify efficient resource cleanup

**Performance Optimization**
- [ ] Test with Instruments
- [ ] Monitor frame rates
- [ ] Check for UI lag
- [ ] Verify smooth animations
- [ ] Test multitasking scenarios

#### 8.8: Battery Usage Optimization

**Power Consumption**
- [ ] Monitor battery usage during capture
- [ ] Test with different screen brightness
- [ ] Check background activity
- [ ] Verify efficient camera usage
- [ ] Test with different capture frequencies

**Optimization Testing**
- [ ] Test power-saving modes
- [ ] Verify efficient processing
- [ ] Check for unnecessary wake-ups
- [ ] Test with different trigger settings
- [ ] Monitor thermal impact on battery

### Test Data Collection

**Metrics to Record**
- Capture latency (target: < 1s)
- Memory usage (target: < 500MB)
- CPU usage (target: < 80%)
- Battery drain per hour
- Storage usage per session
- Thermal performance
- Crash frequency
- Recovery success rate

**Success Criteria**
- ≥95% of sessions complete without manual intervention
- ≤0.5% app crashes over 1,000 sessions
- ≤1s shutter latency from trigger
- Export bundle organized by stock number with metadata JSON

### Test Execution

1. **Pre-Test Setup**
   - Install app on test device
   - Complete onboarding
   - Configure frame box
   - Set up test environment

2. **Test Execution**
   - Run each test case systematically
   - Record all metrics and observations
   - Document any issues or failures
   - Take screenshots of problems

3. **Post-Test Analysis**
   - Compile test results
   - Identify performance issues
   - Document optimization opportunities
   - Create bug reports for issues

### Reporting

**Test Report Template**
- Device information (model, iOS version)
- Test environment details
- Test results for each case
- Performance metrics
- Issues found and severity
- Recommendations for fixes
- Overall pass/fail status

### Notes

- Test on both iPhone 15 Pro and Pro Max
- Use consistent test conditions
- Document all variations
- Record video of critical issues
- Maintain test data for analysis
