# Git Hooks for ClipCook Backend

## Overview
Pre-commit hooks that automatically run quality checks before allowing commits. These hooks prevent common mistakes and ensure code quality.

## Installation

### Automatic (Recommended)
Hooks are automatically installed when you run:
```bash
npm install
```

### Manual
If you need to reinstall hooks manually:
```bash
cd backend/.git-hooks
./install.sh
```

## What Gets Checked

### 🚫 Blocking Checks (Commit will fail)
These checks will prevent the commit if they fail:

1. **Direct commits to main/master**
   - Prevents accidental commits to protected branches
   - Forces use of feature branches

2. **TypeScript build errors**
   - Ensures code compiles before committing
   - Catches type errors early

3. **Hardcoded secrets/API keys**
   - Detects patterns like `apiKey = "sk-..."`
   - Prevents accidental credential leaks

4. **Test failures**
   - Runs unit tests before committing
   - Ensures new code doesn't break existing tests

### ⚠️ Warning Checks (Commit will succeed with warnings)
These checks provide helpful warnings but don't block commits:

1. **Console.log statements**
   - Suggests using `logger` instead
   - Helps maintain production-ready logging

2. **TODOs/FIXMEs**
   - Reminds you to create GitHub issues
   - Prevents technical debt from accumulating

3. **Large files**
   - Warns about files > 1MB
   - Helps catch accidentally committed build artifacts

4. **Unvalidated environment variables**
   - Detects new `process.env` usage
   - Reminds you to add validation in `envValidator.ts`

## Bypassing Hooks

**Use sparingly!** Only bypass when absolutely necessary:

```bash
git commit --no-verify -m "Emergency hotfix"
```

### When it's okay to bypass:
- ✓ Emergency production hotfix
- ✓ Reverting a broken commit
- ✓ Fixing the hooks themselves

### When it's NOT okay:
- ✗ "I'll fix the tests later"
- ✗ "It's just a small change"
- ✗ "The build error isn't important"

## Troubleshooting

### Hook doesn't run
```bash
# Verify hook is installed
ls -la ../.git/hooks/pre-commit

# Reinstall if missing
./install.sh
```

### Hook fails unexpectedly
```bash
# Run checks manually to see detailed output
cd backend
npm run build
npm run test:unit
```

### Permission denied
```bash
chmod +x .git/hooks/pre-commit
```

## Customizing Hooks

To modify the checks:
1. Edit `.git-hooks/pre-commit`
2. Reinstall: `./install.sh`
3. Test: `git commit` (will run hook)

## Why We Use Hooks

Without hooks, these issues have reached production:
- Missing environment variables crashed the server
- Hardcoded API keys were committed
- Failing tests were merged
- Broken TypeScript code was pushed

Hooks catch these issues **before** they cause problems.

## Related Documentation
- [Environment Variables](../docs/RAILWAY_DEPLOYMENT.md#environment-variables)
- [Testing Guide](../tests/README.md)
- [Contributing Guidelines](../../CONTRIBUTING.md)
