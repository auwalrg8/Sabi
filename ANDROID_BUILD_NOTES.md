# Android Build Configuration - Breez SDK Issue

## Problem

The `breez_sdk` Dart package (currently `0.4.1`) has incomplete Android build configuration and missing binary dependencies:

1. **Missing `namespace` in Android library configuration** — required by Android Gradle Plugin 8.0+
2. **Missing `compileSdkVersion`** — not set in the library's `build.gradle`
3. **Missing binary dependency** — `breez_sdk:bindings-android:0.4.1` is not published in any Maven repository

## Current Status

- Web builds are **not supported** because `breez_sdk` is FFI-only (native) and cannot compile to JavaScript.
- Android builds **fail** due to missing binary dependencies.
- The Breez SDK should be managed primarily on the backend (as you configured), so the frontend doesn't require direct SDK access.

##Recommended Solutions

### Option 1: Remove Breez SDK from Frontend (Recommended)
Since the Breez SDK API key is managed on the backend and the frontend doesn't need direct access:

1. Remove `breez_sdk` from `pubspec.yaml`:
   ```bash
   flutter pub remove breez_sdk
   ```
2. Clean up any imports in the codebase related to `breez_sdk` (check `lib/core/services/breez_sdk_service.dart`).
3. Build and run normally on Android.

### Option 2: Patch Android Build (Workaround)
Applied patches to `android/build.gradle.kts`:
1. Added `kotlinx-serialization` plugin to root build.gradle
2. Added logic to set `compileSdk = 34` and `namespace = "com.breez.breez_sdk"` for library subprojects
3. Manually patched breez_sdk's build.gradle in the Pub cache

However, this does **not** resolve the missing binary dependency issue. The breez_sdk package still requires `breez_sdk:bindings-android`, which is unavailable.

### Option 3: Wait for Newer Version
Upgrade to a newer breez_sdk release that fixes these issues (if available on pub.dev).

## For Now

Since the backend handles Breez SDK management, **Option 1 is recommended**: remove the package from the frontend and continue with backend integration only.

If you need the Breez SDK on the frontend later, consider:
- Opening an issue with the breez_sdk maintainers
- Using a build flag to exclude Android native code for this package
- Waiting for a maintenance release with proper Android binary distributions

