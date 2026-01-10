---
description: Protocol for reviewing and pushing code changes
---

# 📜 Review & Push Protocol

Every code change MUST go through this "Council Review" before being pushed.

## 🏛 Council Review Table

| Persona | Analysis & Feedback | Verified? |
| :--- | :--- | :--- |
| **Architect** | Does this change align with the overall project structure and long-term goals? | [ ] |
| **Risk-team** | Are there any security vulnerabilities, performance regressions, or breaking changes? | [ ] |
| **Testing** | Is there adequate test coverage? Are there new edge cases to consider? | [ ] |
| **The-perfectionist** | Is the code clean, well-formatted, and free of typos or "orphan" UI words? | [ ] |

## ⚡ Review Mode Selection

Choose the appropriate review mode based on the scope of the change:

### 🟢 Small/Urgent Fixes (Self-Review)
Use self-review when:
- Fixing a production outage or critical bug
- Changes touch ≤3 files with minimal logic changes
- Simple dependency updates or config tweaks

For self-review: Analyze the change from each persona's perspective yourself, document findings in the table, and proceed.

### 🔴 Larger Changes (Sub-Agent Review)
**MUST run council review script** when:
- Changes touch 4+ files
- Introducing new features or significant refactors
- Database schema changes or API contract changes
- Any change that could affect multiple parts of the system

## 🤖 Running the Council Review

For larger changes, use the single-command council review script:

### Option 1: Review staged changes
```bash
// turbo
.agent/scripts/council_review.sh
```

### Option 2: Review a specific commit
```bash
// turbo
.agent/scripts/council_review.sh <commit-hash>
```

### Option 3: Review with verbose output
```bash
// turbo
.agent/scripts/council_review.sh --verbose
```

The script will:
1. Spawn **4 Claude sub-agents in parallel** (Architect, Risk-team, Testing, The-perfectionist)
2. Each reviews the diff from their persona's perspective
3. Aggregate results into a summary table
4. Output a **FINAL VERDICT**: APPROVED, CONCERNS, or BLOCKED

### Understanding the Verdict

| Verdict | Meaning | Action |
|---------|---------|--------|
| ✅ APPROVED | All personas approve | Safe to push |
| ⚠️ CONCERNS | Some concerns raised | Review and address if warranted |
| ⛔ BLOCKED | Critical issues found | Must fix before pushing |

Detailed reports are saved to `/tmp/council_review_output/` for reference.

## 🚀 Execution Steps

1. **Determine Review Mode**: Small/urgent → self-review. Larger → run council script.
2. **Run Council Review**: Execute script and review the final verdict.
3. **Address Blockers**: If BLOCKED, fix all critical issues before proceeding.
4. **Build Check**: Run `npm run build` or equivalent to ensure no build errors.
5. **Test Check**: Run any available tests.
6. **Documentation**: Ensure any major changes are documented.
7. **Push**: Only once all boxes are checked AND final verdict is APPROVED or CONCERNS addressed, push the code.
