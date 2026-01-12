# Snapshot Testing Setup Guide

This document explains how to enable snapshot testing in ClipCook.

## Step 1: Add swift-snapshot-testing Package

1. Open `ClipCook.xcodeproj` in Xcode
2. Select the project in the Project Navigator
3. Select **Package Dependencies** tab
4. Click the **+** button
5. Enter the repository URL:
   ```
   https://github.com/pointfreeco/swift-snapshot-testing
   ```
6. Set **Dependency Rule** to "Up to Next Major Version" with minimum `1.15.0`
7. Click **Add Package**
8. When prompted to choose targets, select **ClipCookTests** only (NOT the main app)

## Step 2: Enable the Tests

In the snapshot test files, uncomment the `import SnapshotTesting` line and the test implementations:

- `RecipeCardSnapshotTests.swift`
- `FeedViewSnapshotTests.swift`

## Step 3: Record Initial Snapshots

The first time you run the tests, they will fail because there are no baseline snapshots. This is expected.

1. Open any snapshot test file
2. Add `isRecording = true` in `setUpWithError()`:
   ```swift
   override func setUpWithError() throws {
       isRecording = true  // Add this line
       continueAfterFailure = false
   }
   ```
3. Run the tests (⌘U)
4. Snapshots will be recorded to `__Snapshots__` folders
5. **IMPORTANT**: Remove `isRecording = true` after recording
6. Run tests again - they should now pass

## Step 4: Commit Snapshots

Commit the `__Snapshots__` folders to git:
```bash
git add ClipCook/ClipCookTests/__Snapshots__
git commit -m "chore: Add baseline snapshot images"
```

## CI Considerations

Snapshots generated on your Mac may differ slightly from GitHub Actions runners due to:
- Different font rendering
- Different color spaces
- Different simulator versions

**Recommended**: Generate baseline snapshots on CI to avoid false failures.

## Updating Snapshots

When you intentionally change the UI:
1. Set `isRecording = true` in tests
2. Run tests to record new snapshots
3. Review the new snapshots in `__Snapshots__` folders
4. Remove `isRecording = true`
5. Commit the updated snapshots
