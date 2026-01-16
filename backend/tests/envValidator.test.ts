/**
 * Tests for Environment Variable Validator
 */

import {
    validateEnvironmentVariables,
    getEnvironmentSummary
} from '../src/utils/envValidator';

describe('Environment Variable Validator', () => {
    // Store original env vars
    let originalEnv: NodeJS.ProcessEnv;

    beforeEach(() => {
        // Save original environment
        originalEnv = { ...process.env };
        // Clear all env vars for clean test state
        process.env = {};
    });

    afterEach(() => {
        // Restore original environment
        process.env = originalEnv;
    });

    describe('validateEnvironmentVariables', () => {
        it('should fail when required variables are missing', () => {
            const result = validateEnvironmentVariables();

            expect(result.isValid).toBe(false);
            expect(result.errors.length).toBeGreaterThan(0);

            // Check that all required variables are reported as missing
            const missingVars = result.errors.map(e => e.variable);
            expect(missingVars).toContain('SUPABASE_URL');
            expect(missingVars).toContain('SUPABASE_SERVICE_ROLE_KEY');
            expect(missingVars).toContain('GEMINI_API_KEY');
        });

        it('should pass when all required variables are present and valid', () => {
            // Set all required environment variables
            process.env.SUPABASE_URL = 'https://test.supabase.co';
            process.env.SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test';
            process.env.SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.service';
            process.env.GEMINI_API_KEY = 'test-gemini-api-key';
            process.env.RAPIDAPI_KEY = 'test-rapidapi-key';
            process.env.APNS_KEY = '-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----';
            process.env.APNS_KEY_ID = '1234567890';
            process.env.APPLE_TEAM_ID = 'ABCDEFGHIJ';
            process.env.REVENUECAT_WEBHOOK_SECRET = 'test-secret';

            const result = validateEnvironmentVariables();

            expect(result.isValid).toBe(true);
            expect(result.errors).toHaveLength(0);
        });

        it('should validate URL format for SUPABASE_URL', () => {
            // Set all required vars except SUPABASE_URL
            setValidEnvironment();
            process.env.SUPABASE_URL = 'not-a-url';

            const result = validateEnvironmentVariables();

            expect(result.isValid).toBe(false);
            const urlError = result.errors.find(e => e.variable === 'SUPABASE_URL');
            expect(urlError).toBeDefined();
            expect(urlError?.message).toContain('Must be a valid URL');
        });

        it('should validate APNS_KEY format', () => {
            setValidEnvironment();
            process.env.APNS_KEY = 'invalid-key-format';

            const result = validateEnvironmentVariables();

            expect(result.isValid).toBe(false);
            const keyError = result.errors.find(e => e.variable === 'APNS_KEY');
            expect(keyError).toBeDefined();
            expect(keyError?.message).toContain('BEGIN PRIVATE KEY');
        });

        it('should validate APNS_KEY_ID length', () => {
            setValidEnvironment();
            process.env.APNS_KEY_ID = 'SHORT';

            const result = validateEnvironmentVariables();

            expect(result.isValid).toBe(false);
            const idError = result.errors.find(e => e.variable === 'APNS_KEY_ID');
            expect(idError).toBeDefined();
            expect(idError?.message).toContain('10-character');
        });

        it('should warn about common naming mistakes', () => {
            setValidEnvironment();
            // Add a common mistake
            process.env.SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.wrong';
            delete process.env.SUPABASE_SERVICE_ROLE_KEY;

            const result = validateEnvironmentVariables();

            expect(result.isValid).toBe(false); // Missing correct variable
            const warning = result.warnings.find(w =>
                w.message.includes('SUPABASE_SERVICE_KEY') &&
                w.message.includes('SUPABASE_SERVICE_ROLE_KEY')
            );
            expect(warning).toBeDefined();
        });

        it('should set defaults for optional variables', () => {
            setValidEnvironment();

            // Don't set PORT or NODE_ENV
            delete process.env.PORT;
            delete process.env.NODE_ENV;

            const result = validateEnvironmentVariables();

            expect(result.isValid).toBe(true);
            expect(process.env.PORT).toBe('8080');
            expect(process.env.NODE_ENV).toBe('development');
        });

        it('should warn about mismatched NODE_ENV and ENV_TIER', () => {
            setValidEnvironment();
            process.env.NODE_ENV = 'production';
            process.env.ENV_TIER = 'staging';

            const result = validateEnvironmentVariables();

            expect(result.isValid).toBe(true); // Still valid, just a warning
            const warning = result.warnings.find(w =>
                w.message.includes('NODE_ENV is \'production\'') &&
                w.message.includes('ENV_TIER is \'staging\'')
            );
            expect(warning).toBeDefined();
        });

        it('should warn about production without staging validation', () => {
            setValidEnvironment();
            process.env.ENV_TIER = 'production';
            process.env.STAGING_VALIDATED = 'false';

            const result = validateEnvironmentVariables();

            expect(result.isValid).toBe(true); // Still valid, just a warning
            const warning = result.warnings.find(w =>
                w.message.includes('production without staging validation')
            );
            expect(warning).toBeDefined();
        });
    });

    describe('getEnvironmentSummary', () => {
        it('should return comprehensive environment summary', () => {
            setValidEnvironment();
            process.env.NODE_ENV = 'staging';
            process.env.ENV_TIER = 'staging';

            const summary = getEnvironmentSummary();

            expect(summary.isValid).toBe(true);
            expect(summary.nodeEnv).toBe('staging');
            expect(summary.envTier).toBe('staging');
            expect(summary.errors).toBe(0);
            expect(summary.requiredVariables.SUPABASE_URL).toBe('✅ Set');
            expect(summary.requiredVariables.GEMINI_API_KEY).toBe('✅ Set');
        });

        it('should show missing variables in summary', () => {
            // Don't set any variables
            const summary = getEnvironmentSummary();

            expect(summary.isValid).toBe(false);
            expect(summary.errors).toBeGreaterThan(0);
            expect(summary.requiredVariables.SUPABASE_URL).toBe('❌ Missing');
            expect(summary.requiredVariables.GEMINI_API_KEY).toBe('❌ Missing');
        });

        it('should show defaults for optional variables', () => {
            setValidEnvironment();
            delete process.env.PORT;

            const summary = getEnvironmentSummary();

            // After validation runs, PORT is set to its default value
            // So we should see the actual value, not the default notation
            expect(summary.optionalVariables.PORT).toBe('8080');
        });
    });
});

// Helper function to set valid environment
function setValidEnvironment() {
    process.env.SUPABASE_URL = 'https://test.supabase.co';
    process.env.SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test';
    process.env.SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.service';
    process.env.GEMINI_API_KEY = 'test-gemini-api-key';
    process.env.RAPIDAPI_KEY = 'test-rapidapi-key';
    process.env.APNS_KEY = '-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----';
    process.env.APNS_KEY_ID = '1234567890';
    process.env.APPLE_TEAM_ID = 'ABCDEFGHIJ';
    process.env.REVENUECAT_WEBHOOK_SECRET = 'test-secret';
}