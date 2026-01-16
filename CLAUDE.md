# ClipCook Project Configuration

## Project Overview
ClipCook is an iOS app with a Node.js/TypeScript backend that transforms viral recipe videos into structured, interactive cooking experiences powered by AI.

## Tech Stack

### iOS App
- **Language**: Swift 5.9+, SwiftUI
- **Minimum iOS**: 17.0
- **Architecture**: MVVM with service layer

### Backend
- **Runtime**: Node.js 20+ (ESM-compatible)
- **Language**: TypeScript
- **Framework**: Express.js
- **Database**: Supabase (PostgreSQL)
- **AI**: Google Gemini API
- **Deployment**: Railway

## Project-Specific Rules

1. **Feature Branches**: For any new feature or changes touching 5+ files, create a feature branch first following `/branching-strategy`
2. **No Model Downgrades**: Never downgrade AI model versions (e.g., Gemini 3 → Gemini 2)
3. **Verify AI Models**: Follow `.agent/workflows/verify_ai_models.md` before changing model names
4. **Build Before Push**: Always run `npm run build` in backend before committing
5. **No Orphan Words**: UI text should never have a single word wrapping to its own line
6. **Pre-Release Check**: Run `/pre-release-checklist` before any TestFlight submission

## iOS Platform Rules

### UIKit Appearance Configuration
**CRITICAL: UIKit appearance proxies can break SwiftUI apps on new iOS versions**

1. **Always use iOS version checks** when configuring UIKit appearance (tab bars, nav bars, etc.):
   ```swift
   if #available(iOS 26.0, *) {
       // iOS 26+ specific configuration (Liquid Glass)
       return
   }
   // Pre-iOS 26 configuration
   ```

2. **iOS 26 Liquid Glass**: iOS 26 introduced floating, translucent system UI components
   - Do NOT use `configureWithOpaqueBackground()` on iOS 26 for tab bars
   - Do NOT set `isTranslucent = false` on iOS 26 tab bars
   - Let the system handle Liquid Glass appearance; only set tint colors

3. **When SwiftUI UI fixes don't work, check UIKit layer**:
   - `UIKitAppearance.swift` or similar appearance configuration files
   - UIKit appearance proxies affect SwiftUI even in "pure SwiftUI" apps

4. **Tab Bar Troubleshooting** (see `docs/postmortems/2026-01-16-ios26-tab-bar-grey-gap.md`):
   - Grey gaps behind tab bar = likely UIKit appearance conflict
   - Use `.toolbarBackground(.hidden, for: .tabBar)` on each tab content
   - Use `.toolbarColorScheme(.dark, for: .tabBar)` for dark themes

### Navigation
- Use `NavigationStack` (iOS 16+), NOT deprecated `NavigationView`
- Apply `.ignoresSafeArea(.all)` for backgrounds that should extend edge-to-edge

### Before Modifying System UI Configuration
1. Check what iOS version introduced relevant changes (WWDC videos, release notes)
2. Test on BOTH the latest iOS AND minimum supported iOS (17.0)
3. Use `#available` checks for version-specific behavior
4. When in doubt, spawn the `ios-migration-architect` sub-agent for platform expertise

## Common Commands

```bash
# Backend
cd backend && npm run build     # Build TypeScript
cd backend && npm run dev       # Development server

# iOS
open ClipCook/ClipCook.xcodeproj  # Open in Xcode
```
