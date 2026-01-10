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

1. **No Model Downgrades**: Never downgrade AI model versions (e.g., Gemini 3 → Gemini 2)
2. **Verify AI Models**: Follow `.agent/workflows/verify_ai_models.md` before changing model names
3. **Build Before Push**: Always run `npm run build` in backend before committing
4. **No Orphan Words**: UI text should never have a single word wrapping to its own line

## Common Commands

```bash
# Backend
cd backend && npm run build     # Build TypeScript
cd backend && npm run dev       # Development server

# iOS
open ClipCook/ClipCook.xcodeproj  # Open in Xcode
```
