---
description: Branching strategy for feature development and safety
---

# 🌿 Branch Strategy Workflow

Automatically create feature branches for significant work to ensure safety and easy rollbacks.

## When to Create a Feature Branch

**MUST create a branch when:**
- Adding a new feature or capability
- Changes will touch 5+ files
- Modifying database schema
- Changing authentication/authorization logic
- Any experimental or risky changes
- User explicitly requests a new feature

**Can stay on main for:**
- Bug fixes affecting ≤3 files
- Documentation updates
- Config/copy changes
- Refactoring within a single file

## Branch Naming Convention

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/<short-description>` | `feature/voice-improvements` |
| Bug fix | `fix/<issue-description>` | `fix/recipe-save-crash` |
| Hotfix | `hotfix/<urgent-fix>` | `hotfix/auth-bypass` |
| Chore | `chore/<task>` | `chore/update-dependencies` |

## Automatic Branch Creation

When starting significant work, run:
```bash
# 1. Ensure we're on latest main
git checkout main
git pull origin main

# 2. Create feature branch
git checkout -b feature/<branch-name>

# 3. Confirm branch
git branch --show-current
```

## During Development

```bash
# Commit often with clear messages
git add .
git commit -m "feat: Add step 0 audio playback"

# Push to remote periodically
git push -u origin feature/<branch-name>
```

## Completing the Feature

// turbo
1. Ensure all tests pass locally
2. Run the council review protocol (`/review_and_push`)
3. Push final changes to feature branch
4. Create a Pull Request on GitHub
5. After PR approval, merge to main
6. Delete the feature branch:
```bash
git checkout main
git pull
git branch -d feature/<branch-name>
```

## Emergency: Abort Feature

If the feature is broken and needs to be abandoned:
```bash
git checkout main
git branch -D feature/<branch-name>  # Force delete
```

## Agent Instructions

When an agent starts work on a new user request:

1. **Assess scope**: Count expected file changes, evaluate risk
2. **If branch needed**: 
   - Ask user for a short feature name if not obvious
   - Create branch before making any changes
   - Include branch name in task status
3. **If no branch needed**: 
   - Proceed on current branch
   - Note in task summary: "Small fix, staying on current branch"
