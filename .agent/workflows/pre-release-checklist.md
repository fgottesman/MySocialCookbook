---
description: Pre-App Store release checklist to prevent regressions
---

# 🚀 Pre-Release Checklist

Run this checklist before every TestFlight or App Store submission.

## ⚡ Quick Commands

```bash
# Run all tests locally
cd ClipCook/ClipCook
xcodebuild test -project ClipCook.xcodeproj -scheme ClipCook -destination 'platform=iOS Simulator,name=iPhone 15'

# Or if you have Fastlane set up:
cd ClipCook/ClipCook && fastlane test
```

## 📋 Checklist

### 🧪 Automated Testing
- [ ] All unit tests pass (`ClipCookTests`)
- [ ] All UI tests pass (`ClipCookUITests`)
- [ ] Snapshot tests show no unintended UI changes (if applicable)
- [ ] Backend tests pass (`npm test` in backend/)

### 📱 Device Compatibility
- [ ] App launches without crash on **iPhone 15** simulator
- [ ] App launches without crash on **iPhone SE** simulator (small screen)
- [ ] App launches without crash on **iPad Pro** simulator
- [ ] UI elements are properly sized on all device types
- [ ] No single-word "orphans" wrapping to their own line

### 🔗 Core Functionality Smoke Test
- [ ] User can sign in with Apple
- [ ] User can paste a recipe link and it processes successfully
- [ ] User can create a recipe from a text prompt
- [ ] Recipe feed displays correctly
- [ ] User can tap into a recipe and view details
- [ ] User can start cooking flow with voice companion
- [ ] User can remix a recipe
- [ ] Favorites can be added/removed
- [ ] Share extension works (share link from Safari → ClipCook)

### 🔔 Notifications & Permissions
- [ ] Push notifications for "recipe ready" work
- [ ] Microphone permission is requested correctly for voice companion
- [ ] Deep links work (if applicable)

### 🔐 Security & Privacy
- [ ] No hardcoded debug URLs in release build
- [ ] No hardcoded API keys exposed in client code
- [ ] Privacy manifest is up to date (if required)

### 📈 Performance
- [ ] App launches within 2 seconds on iPhone 15
- [ ] Memory usage stays under 200MB during normal use
- [ ] No memory leaks detected (run Instruments Leaks)
- [ ] No obvious jank/stuttering in animations

### 🔢 Versioning
- [ ] Build number incremented from previous TestFlight
- [ ] Marketing version updated if needed (major/minor release)
- [ ] All version numbers consistent across targets:
  - ClipCook app
  - ClipCookTests
  - ClipCookUITests
  - ShareRecipe extension

### 📝 Final Review
- [ ] Council Review passed (if 4+ files changed)
- [ ] No TODO/FIXME comments left for critical issues
- [ ] No `print()` or debug logging left in production code
- [ ] Changes documented in release notes

## 🎯 Sign-Off

| Reviewer | Date | Status |
|----------|------|--------|
| Developer | | ☐ Ready |
| QA (if applicable) | | ☐ Approved |

---

**Once all items are checked, you're ready to submit to TestFlight!** 🎉
