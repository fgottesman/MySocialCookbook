# Railway Deployment Configuration

## Overview
ClipCook uses a tier-based deployment strategy with Railway:
- **Staging**: Auto-deploys from `main` branch
- **Production**: Deploys only from tags matching `deploy-prod-*`

This ensures production deployments only happen after staging validation passes.

## Setup Instructions

### 1. Railway Dashboard Configuration

#### Staging Environment
1. Go to your Railway project dashboard
2. Select the **Staging** environment
3. Navigate to **Settings** > **Deploy**
4. Configure:
   - **Deployment Trigger**: GitHub Branch
   - **Branch**: `main`
   - **Auto Deploy**: Enabled

#### Production Environment
1. Go to your Railway project dashboard
2. Select the **Production** environment
3. Navigate to **Settings** > **Deploy**
4. Configure:
   - **Deployment Trigger**: GitHub Tag
   - **Tag Pattern**: `deploy-prod-*`
   - **Auto Deploy**: Enabled

### 2. Environment Variables

#### Required Variables (Both Environments)
```bash
# Supabase
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...

# AI Services
GEMINI_API_KEY=your_gemini_key
RAPIDAPI_KEY=your_rapidapi_key

# Apple Push Notifications
APNS_KEY=-----BEGIN PRIVATE KEY-----...
APNS_KEY_ID=XXXXXXXXXX
APPLE_TEAM_ID=XXXXXXXXXX

# RevenueCat
REVENUECAT_WEBHOOK_SECRET=your_webhook_secret

# Environment
NODE_ENV=staging  # or 'production' for prod
ENV_TIER=staging  # or 'production' for prod
```

#### Additional Production Variables
```bash
NODE_ENV=production
ENV_TIER=production
APNS_ENV=production
```

### 3. GitHub Actions Variables

Add these to your GitHub repository settings under **Settings** > **Secrets and variables** > **Variables**:

```bash
STAGING_URL=https://your-staging-url.railway.app
```

## Deployment Flow

### Automatic Staging Deployment
1. Push code to `main` branch
2. GitHub Actions runs local validation
3. Railway auto-deploys to staging
4. GitHub Actions polls staging health

### Production Deployment (Automated)
1. If staging health check passes:
   - GitHub Actions creates tag `deploy-prod-{sha}-{timestamp}`
   - Railway automatically deploys tagged version to production

### Production Deployment (Manual)
If you need to manually deploy to production:

```bash
# Create a production deploy tag
git tag deploy-prod-manual-$(date +%Y%m%d-%H%M%S)
git push origin --tags
```

## Monitoring & Debugging

### Check Deployment Status
```bash
# View recent deployments
railway logs --environment=staging
railway logs --environment=production

# Check health endpoints
curl https://staging.railway.app/health
curl https://production.railway.app/health/environment
```

### Rollback Production
```bash
# Find previous successful deployment tag
git tag -l "deploy-prod-*" | tail -5

# Deploy specific tag to production
git push origin :refs/tags/deploy-prod-rollback
git tag deploy-prod-rollback <previous-good-sha>
git push origin deploy-prod-rollback
```

## Environment Validation

The backend now includes automatic environment variable validation at startup.
If critical variables are missing, the server will not start and will log detailed error messages.

### Check Environment Status
```bash
# Check environment validation
curl https://your-app.railway.app/api/health/environment
```

### Common Issues

#### Server won't start
- Check Railway logs for `[EnvValidator]` messages
- Verify all required environment variables are set
- Common mistake: `SUPABASE_SERVICE_KEY` should be `SUPABASE_SERVICE_ROLE_KEY`

#### Staging health check fails
- Ensure STAGING_URL is set in GitHub variables
- Check that staging has all required environment variables
- Verify Railway is actually deploying (check Railway dashboard)

#### Production not deploying
- Verify tag pattern matches `deploy-prod-*`
- Check that staging health passed (look for green checkmark in GitHub Actions)
- Ensure production environment in Railway is configured for tag-based deploys

## Security Notes

1. **Never commit secrets**: All sensitive values should be in Railway environment variables
2. **Webhook verification**: RevenueCat webhooks are now verified with HMAC-SHA256
3. **Environment isolation**: Staging and production use separate Supabase projects/keys
4. **Audit trail**: All deployments are tagged for traceability

## Support

For deployment issues:
1. Check Railway deployment logs
2. Review GitHub Actions workflow runs
3. Verify environment variables with `/api/health/environment` endpoint
4. Check the audit tags in Git for deployment history