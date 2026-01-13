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

## Common Commands

```bash
# Backend
cd backend && npm run build     # Build TypeScript
cd backend && npm run dev       # Development server

# iOS
open ClipCook/ClipCook.xcodeproj  # Open in Xcode
```
