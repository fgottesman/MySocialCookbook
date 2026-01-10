# Share Extension Reliability - Documentation

## E2E Test Setup

### Prerequisites
- Node.js and npm installed
- Backend server running (locally or staging)
- Test user ID from Supabase

### Running Tests

```bash
# Run all tests
npm run test:all

# Run E2E tests only
npm run test:e2e

# Run legacy Share Extension test
npm run test:share-extension
```

### Configuration

Set these environment variables for E2E tests:

```bash
# Required
TEST_USER_ID=your-test-user-uuid

# Optional (for modern auth tests)
TEST_AUTH_TOKEN=your-test-jwt-token

# Optional (defaults to localhost)
TEST_API_URL=https://mysocialcookbook-production.up.railway.app/api
```

---

## Health Check Endpoint

### Endpoint
`GET /api/health/share-extension`

### Rate Limiting
- **Limit:** 30 requests per minute per IP
- **Response on limit:** 429 Too Many Requests

### Response Format

```json
{
  "overall": "healthy",
  "timestamp": "2026-01-10T15:30:00.000Z",
  "services": {
    "database": {
      "healthy": true,
      "message": "Database connection successful"
    },
    "gemini": {
      "healthy": true,
      "message": "Gemini API accessible"
    },
    "storage": {
      "healthy": true,
      "message": "Supabase Storage accessible"
    },
    "rapidapi": {
      "healthy": true,
      "message": "RapidAPI accessible"
    }
  }
}
```

### Overall Status Values
- `healthy` - All services operational (200 OK)
- `degraded` - One service down (200 OK)
- `unhealthy` - Multiple services down (503 Service Unavailable)

### Usage Examples

**cURL:**
```bash
curl https://your-api.com/api/health/share-extension
```

**Monitoring Script:**
```bash
#!/bin/bash
response=$(curl -s https://your-api.com/api/health/share-extension)
status=$(echo $response | jq -r '.overall')

if [ "$status" != "healthy" ]; then
  echo "ALERT: API status is $status"
  # Send alert
fi
```

---

## Schema Guard Troubleshooting

### What It Does
The Schema Guard validates that all required database columns exist before the server starts. This prevents runtime errors from schema drift.

### Common Issues

#### 1. Server Won't Start - Missing Columns

**Error:**
```
[SchemaGuard] ❌ Table 'recipes' is missing required columns: difficulty, cooking_time
This usually means migrations were not run. Please run the latest migrations before starting the server.
```

**Solution:**
1. Run pending migrations in Supabase SQL Editor
2. Check `/backend/migrations/` for recent migration files
3. Restart the server

#### 2. Emergency Bypass Needed

If there's a false positive blocking deployment:

**Railway/Production:**
```bash
# Add environment variable
SKIP_SCHEMA_CHECK=true

# Restart server
# Then IMMEDIATELY remove this variable and fix the root cause
```

**Local:**
```bash
SKIP_SCHEMA_CHECK=true npm run dev
```

⚠️ **WARNING:** This is an EMERGENCY bypass only. The server will log loud warnings. Remove this variable as soon as possible and fix the actual schema issue.

#### 3. Schema Check Timeout

If the schema check takes too long:
- Check Supabase dashboard for database issues
- Verify `SUPABASE_SERVICE_ROLE_KEY` is set correctly
- Check network connectivity to Supabase

### Adding New Required Columns

When adding new columns to the code:

1. **Write the migration:**
   ```sql
   ALTER TABLE recipes ADD COLUMN new_field text;
   ```

2. **Update `schemaGuard.ts`:**
   ```typescript
   const REQUIRED_SCHEMA: RequiredColumns = {
       recipes: [
           // ... existing columns
           'new_field' // Add here
       ]
   };
   ```

3. **Test locally:**
   ```bash
   # Run migration
   # Start server - should pass schema guard
   npm run dev
   ```

4. **Deploy:**
   - Run migration in production
   - Deploy new code
   - Server will validate schema on startup

---

## Sheriff Patrol Integration

The  sheriff agent should monitor health status every 15 minutes.

### Add to Sheriff Script

```typescript
// Check health endpoint
const response = await axios.get('https://api/health/share-extension');
if (response.data.overall !== 'healthy') {
  // Send alert
  sendAlert(`API Health: ${response.data.overall}`);
}
```

### Expected Behavior
- Every 15 minutes: Check health endpoint
- If `degraded` or `unhealthy`: Send alert
- Log recent failures from application logs
