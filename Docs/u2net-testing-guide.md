# Testing U2Net Background Removal

This document explains how to test the U2Net background removal library alongside your existing background removal pipeline.

## What Was Added

1. **U2NetBackgroundRemover.swift** - A wrapper class for the U2-Net based BackgroundRemoval library
2. **Integration in BackgroundRemover.swift** - Added as an optional fallback method
3. **useU2NetFallback flag** - Toggle to enable/disable U2Net testing

## Current Background Removal Pipeline

Your app uses a multi-layered approach (in order):

1. **Primary**: Vision Framework (VNGenerateForegroundInstanceMaskRequest) - iOS 17+
2. **Enhancement 1**: DeepLab V3 semantic segmentation
3. **Enhancement 2**: YOLO v3 for vehicle/person bounding boxes
4. **Enhancement 3**: LiDAR depth data (when available)
5. **Fallback 1**: Apple Subject Lift (VisionKit) - iOS 16+
6. **Fallback 2**: U2Net (NEW - optional, disabled by default)
7. **Fallback 3**: Simple brightness-based removal (legacy)

## How to Add the U2Net Package

### Option 1: Using Xcode GUI (Recommended)

1. Open `iCapture.xcodeproj` in Xcode
2. Select the **iCapture** project in the navigator
3. Select the **iCapture** target
4. Go to the **Package Dependencies** tab
5. Click the **+** button
6. Enter the URL: `https://github.com/Ezaldeen99/BackgroundRemoval.git`
7. Select **"Up to Next Major Version"** starting from `1.0.0`
8. Click **Add Package**
9. Select **BackgroundRemoval** library and click **Add Package**

### Option 2: Manually Edit Package.resolved

Add this to your `Package.resolved`:

```json
{
  "identity" : "backgroundremoval",
  "kind" : "remoteSourceControl",
  "location" : "https://github.com/Ezaldeen99/BackgroundRemoval.git",
  "state" : {
    "revision" : "main",
    "version" : "1.0.0"
  }
}
```

## How to Enable U2Net for Testing

### Step 1: Uncomment the Code in U2NetBackgroundRemover.swift

Open `iCapture/Core/U2NetBackgroundRemover.swift` and:

1. Add the import at the top:
```swift
import BackgroundRemoval
```

2. Uncomment the actual implementation in the `removeBackground` method:
```swift
let backgroundRemoval = BackgroundRemoval()
let outputImage = try backgroundRemoval.removeBackground(image: image)
return outputImage
```

3. Uncomment the mask generation code in the `getMask` method.

### Step 2: Enable the Flag in Your Code

In any view or manager where you use `BackgroundRemover`, enable the flag:

```swift
// In CameraManager or wherever you use BackgroundRemover
let backgroundRemover = BackgroundRemover()
backgroundRemover.useU2NetFallback = true
```

Or for testing in a specific view:

```swift
// In CameraView or QATestingView
@StateObject private var backgroundRemover = BackgroundRemover()

var body: some View {
    // ... your view code
    .onAppear {
        backgroundRemover.useU2NetFallback = true
    }
}
```

## Testing Strategy

### Test 1: Compare Quality

1. Take the same photo with U2Net disabled and enabled
2. Compare the background removal quality
3. Check edge detection, especially around:
   - Vehicle wheels and undercarriage
   - Complex curves (mirrors, bumpers)
   - Glass/reflective surfaces
   - Shadows

### Test 2: Performance

Monitor these metrics:

- **Processing time**: Check console logs for timing
- **Memory usage**: Watch for spikes in Xcode memory debugger
- **Battery impact**: Test during a full photo session
- **CPU/GPU usage**: Use Instruments

### Test 3: Fallback Behavior

Test scenarios where primary methods fail:

- Poor lighting conditions
- Cluttered backgrounds
- Partial vehicle visibility
- Moving subjects

## Expected Behavior

### When U2Net is DISABLED (default):
```
BackgroundRemover: Applying foreground + (optional) depth mask
BackgroundRemover: Mask fusion summary [Vision ✓, DeepLab ✓, Depth ×, YOLO ✓]
```

### When U2Net is ENABLED and primary methods succeed:
```
BackgroundRemover: Applying foreground + (optional) depth mask
BackgroundRemover: Mask fusion summary [Vision ✓, DeepLab ✓, Depth ×, YOLO ✓]
(U2Net not called because primary methods succeeded)
```

### When U2Net is ENABLED and becomes fallback:
```
BackgroundRemover: Foreground segmentation failed: [error]
BackgroundRemover: Apple subject lift unsupported on this device (vision-request-error)
BackgroundRemover: Attempting U2Net fallback (vision-request-error)
U2NetBackgroundRemover: Successfully removed background in 523ms
BackgroundRemover: U2Net fallback succeeded (vision-request-error)
```

## Comparison with Current System

| Feature | Current Pipeline | U2Net |
|---------|-----------------|-------|
| Model | Vision + DeepLab + YOLO | U^2-Net |
| iOS Version | 17+ (16+ for fallback) | iOS 13+ |
| Speed | Very fast (GPU accelerated) | Moderate (~500ms) |
| Accuracy | Excellent for general subjects | Excellent for portraits/objects |
| Edge Quality | Very good | Very good |
| Depth Aware | Yes (with LiDAR) | No |
| Vehicle Specific | Yes (YOLO) | No |
| On-Device | Yes | Yes |
| Model Size | ~20MB + 237MB | ~176MB |

## Troubleshooting

### Package won't download
- Check internet connection
- Try: `File > Packages > Reset Package Caches`
- Restart Xcode

### Build errors
- Make sure you uncommented the import statement
- Clean build folder: `Product > Clean Build Folder` (Cmd+Shift+K)
- Check minimum iOS version (U2Net requires iOS 13+)

### U2Net not being called
- Verify `useU2NetFallback = true`
- Check that primary methods are actually failing (they usually work well)
- Add a breakpoint in `subjectLiftFallback` to debug flow

### Poor results
- U2Net is trained more for portraits than vehicles
- Try adjusting the image preprocessing
- Consider it may not be suitable for your use case

## Recommendation

Based on your master plan requirements:

- **Vehicle photography**: Your current pipeline is already excellent
- **U2Net use case**: Best as emergency fallback for edge cases
- **Keep disabled by default**: Your Vision + DeepLab + YOLO pipeline is specifically tuned for vehicles
- **Test in production**: Enable for 1 week, log which fallback is used, analyze results

## Disabling U2Net

To remove it completely:

1. Set `useU2NetFallback = false` (default)
2. Or remove the package from Xcode dependencies
3. The code will gracefully handle absence of the library

## Questions?

Check console logs prefixed with:
- `U2NetBackgroundRemover:` - U2Net specific logs
- `BackgroundRemover:` - General background removal flow

The integration is **non-invasive** - your existing code continues to work exactly as before unless you explicitly enable the flag.

