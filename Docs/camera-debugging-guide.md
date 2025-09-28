# Camera Orientation Debugging Guide

## Overview
This guide provides a systematic approach to debugging camera orientation issues in the iCapture app. The debugging tools will help identify and resolve problems with camera preview orientation, frame sizing, and UI layout.

## Debug Tools Available

### 1. CameraDebugger
- **Location**: `iCapture/Core/CameraDebugger.swift`
- **Purpose**: Real-time monitoring of camera state, orientation, and preview layer behavior
- **Features**:
  - Device orientation tracking
  - Interface orientation monitoring
  - Preview layer frame analysis
  - Camera session status
  - Connection properties logging

### 2. CameraDebugView
- **Location**: `iCapture/UI/CameraDebugView.swift`
- **Purpose**: Visual debug interface overlay
- **Features**:
  - Real-time debug log display
  - Orientation testing controls
  - Frame analysis tools
  - Export debug logs

## How to Enable Debug Mode

### Method 1: Through QA Testing View
1. Open the app and navigate to the camera view
2. Access the QA Testing panel
3. Toggle "Camera Debug Mode" to ON
4. Debug overlay will appear in the top-left corner

### Method 2: Programmatically
```swift
cameraManager.cameraDebugger.isDebugMode = true
cameraManager.cameraDebugger.startDebugging(cameraManager: cameraManager)
```

## Debug Information Collected

### Device Information
- Device model and iOS version
- Current device orientation
- Interface orientation
- Screen bounds

### Camera Session Information
- Session running status
- Authorization status
- Camera device connection status
- Device suspension status

### Preview Layer Information
- Frame dimensions and position
- Bounds information
- Video gravity setting
- Connection properties
- Video orientation settings

## Common Issues and Solutions

### Issue 1: Black Screen
**Symptoms**: Camera preview shows black screen
**Debug Info to Check**:
- Preview layer frame is (0,0,0,0)
- Session is not running
- Camera device is suspended

**Solutions**:
1. Check camera authorization
2. Restart camera session
3. Verify preview layer frame is set correctly
4. Check for hardware errors in console

### Issue 2: Incorrect Orientation
**Symptoms**: Camera preview is rotated or upside down
**Debug Info to Check**:
- Device orientation vs interface orientation mismatch
- Preview layer connection video orientation
- Frame size vs screen bounds

**Solutions**:
1. Let AVFoundation handle orientation naturally (current approach)
2. Check if preview layer frame updates on rotation
3. Verify connection properties

### Issue 3: UI Overlay Misplacement
**Symptoms**: UI elements positioned incorrectly in different orientations
**Debug Info to Check**:
- Screen bounds changes
- Preview layer frame updates
- Interface orientation changes

**Solutions**:
1. Use proper SwiftUI layout modifiers
2. Ensure UI updates on orientation change
3. Check frame calculations

### Issue 4: Split Screen in Landscape
**Symptoms**: Landscape mode shows half screen black, half camera
**Debug Info to Check**:
- Preview layer frame vs screen bounds
- Video gravity setting
- Frame update timing

**Solutions**:
1. Ensure preview layer frame matches screen bounds
2. Use `.resizeAspectFill` video gravity
3. Update frame on orientation change

## Debug Workflow

### Step 1: Enable Debug Mode
1. Turn on Camera Debug Mode in QA Testing
2. Observe the debug overlay
3. Note initial state information

### Step 2: Test Orientation Changes
1. Rotate device to portrait
2. Check debug info for frame updates
3. Rotate to landscape
4. Verify frame and orientation changes

### Step 3: Analyze Frame Issues
1. Use "Analyze Frame" button
2. Compare preview layer frame to screen bounds
3. Check for zero dimensions
4. Verify video gravity setting

### Step 4: Test Orientation Changes
1. Use "Test Orientation" button
2. Observe debug log for changes
3. Check if notifications are received
4. Verify UI updates

### Step 5: Export Debug Log
1. Use "Export" button to save debug log
2. Share log for analysis
3. Look for patterns in orientation changes
4. Identify timing issues

## Expected Debug Output

### Normal Operation
```
[10:30:15] 🔍 Camera Debugging Started
[10:30:15] 📱 Device: iPhone
[10:30:15] 📱 System: iOS 18.0
[10:30:15] 📱 Orientation: Portrait
[10:30:16] 📱 Device Orientation: Portrait
[10:30:16] 📱 Interface Orientation: Portrait
[10:30:16] 📹 Session Running: true
[10:30:16] 📹 Authorized: true
[10:30:16] 📹 Preview Layer Frame: (0.0, 0.0, 393.0, 852.0)
[10:30:16] 📹 Preview Layer Bounds: (0.0, 0.0, 393.0, 852.0)
[10:30:16] ✅ Frame matches screen bounds
```

### Problematic Operation
```
[10:30:15] 📹 Preview Layer Frame: (0.0, 0.0, 0.0, 0.0)
[10:30:15] ❌ WARNING: Preview layer frame has zero dimensions!
[10:30:15] ❌ Preview Layer: nil
[10:30:15] 📹 Session Running: false
```

## Troubleshooting Steps

### If Debug Mode Doesn't Start
1. Check if camera session is running
2. Verify CameraManager is properly initialized
3. Check for compilation errors in debug files

### If Debug Overlay Doesn't Show
1. Verify debug mode is enabled
2. Check if overlay is positioned correctly
3. Ensure CameraView is the active view

### If Debug Info is Incomplete
1. Check if camera session is authorized
2. Verify preview layer exists
3. Ensure device orientation is being tracked

## Performance Considerations

- Debug mode runs a timer every 1 second
- Debug logs are limited to 50 entries
- Debug overlay may impact performance
- Disable debug mode for production builds

## Integration with Existing QA Tools

The camera debugger integrates with:
- Performance Monitor for session metrics
- QA Testing View for easy access
- Existing camera health checks
- Session management tools

## Next Steps

1. **Enable debug mode** on physical device
2. **Test orientation changes** systematically
3. **Analyze debug output** for patterns
4. **Export logs** for detailed analysis
5. **Implement fixes** based on findings
6. **Verify solutions** with debug tools

This debugging approach will help identify the root cause of camera orientation issues and provide a systematic way to verify fixes.
