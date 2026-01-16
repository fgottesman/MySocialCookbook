/**
 * Environment Variable Validator
 *
 * CRITICAL: This module prevents production crashes from missing environment variables
 * It validates all required variables at startup and provides clear error messages
 *
 * This validator was created after a production crash caused by SUPABASE_SERVICE_KEY
 * being referenced as SUPABASE_SERVICE_ROLE_KEY in the code.
 */

import logger from './logger';

// Define required environment variables and their descriptions
const REQUIRED_VARIABLES = {
    // Supabase Configuration
    SUPABASE_URL: {
        description: 'Supabase project URL (e.g., https://xxx.supabase.co)',
        validator: (value: string) => value.startsWith('http'),
        errorMessage: 'Must be a valid URL starting with http:// or https://'
    },
    SUPABASE_ANON_KEY: {
        description: 'Supabase anonymous/public key for client-side operations',
        validator: (value: string) => value.length > 20,
        errorMessage: 'Must be a valid Supabase key (usually starts with "eyJ")'
    },
    SUPABASE_SERVICE_ROLE_KEY: {
        description: 'Supabase service role key for server-side operations',
        validator: (value: string) => value.length > 20,
        errorMessage: 'Must be a valid Supabase service role key (usually starts with "eyJ")'
    },

    // AI Services
    GEMINI_API_KEY: {
        description: 'Google Gemini API key for recipe analysis and AI features',
        validator: (value: string) => value.length > 10,
        errorMessage: 'Must be a valid Gemini API key'
    },
    RAPIDAPI_KEY: {
        description: 'RapidAPI key for video downloading service',
        validator: (value: string) => value.length > 10,
        errorMessage: 'Must be a valid RapidAPI key'
    },

    // Apple Push Notifications
    APNS_KEY: {
        description: 'Apple Push Notification Service key (p8 file content)',
        validator: (value: string) => value.includes('BEGIN PRIVATE KEY'),
        errorMessage: 'Must be a valid APNS p8 key (should contain "BEGIN PRIVATE KEY")'
    },
    APNS_KEY_ID: {
        description: 'APNS Key ID from Apple Developer Portal',
        validator: (value: string) => value.length === 10,
        errorMessage: 'Must be a 10-character APNS Key ID'
    },
    APPLE_TEAM_ID: {
        description: 'Apple Team ID from Developer Portal',
        validator: (value: string) => value.length === 10,
        errorMessage: 'Must be a 10-character Apple Team ID'
    },

    // RevenueCat Webhook
    REVENUECAT_WEBHOOK_SECRET: {
        description: 'RevenueCat webhook secret for signature verification',
        validator: (value: string) => value.length > 0,
        errorMessage: 'Must not be empty for webhook security'
    }
} as const;

// Define optional environment variables with defaults
const OPTIONAL_VARIABLES = {
    PORT: {
        description: 'Server port (default: 8080)',
        default: '8080',
        validator: (value: string) => !isNaN(parseInt(value)),
        errorMessage: 'Must be a valid port number'
    },
    NODE_ENV: {
        description: 'Node environment (development/staging/production)',
        default: 'development',
        validator: (value: string) => ['development', 'staging', 'production'].includes(value),
        errorMessage: 'Must be one of: development, staging, production'
    },
    ENV_TIER: {
        description: 'Deployment tier for tier validation system',
        default: 'local',
        validator: (value: string) => ['local', 'staging', 'production'].includes(value),
        errorMessage: 'Must be one of: local, staging, production'
    },
    APNS_ENV: {
        description: 'APNS environment override (development/production)',
        default: undefined, // Uses NODE_ENV if not set
        validator: (value: string) => ['development', 'production'].includes(value),
        errorMessage: 'Must be either development or production'
    },
    STAGING_VALIDATED: {
        description: 'Flag indicating staging was validated (for production deploys)',
        default: 'false',
        validator: (value: string) => ['true', 'false'].includes(value),
        errorMessage: 'Must be either true or false'
    },
    SKIP_SCHEMA_CHECK: {
        description: 'Skip schema validation (not recommended for production)',
        default: 'false',
        validator: (value: string) => ['true', 'false'].includes(value),
        errorMessage: 'Must be either true or false'
    }
} as const;

export interface ValidationResult {
    isValid: boolean;
    errors: Array<{
        variable: string;
        message: string;
        description: string;
    }>;
    warnings: Array<{
        variable: string;
        message: string;
    }>;
}

/**
 * Validate all environment variables
 * @returns Validation result with errors and warnings
 */
export function validateEnvironmentVariables(): ValidationResult {
    const errors: ValidationResult['errors'] = [];
    const warnings: ValidationResult['warnings'] = [];

    // Check required variables
    for (const [key, config] of Object.entries(REQUIRED_VARIABLES)) {
        const value = process.env[key];

        if (!value) {
            errors.push({
                variable: key,
                message: `Missing required environment variable: ${key}`,
                description: config.description
            });
        } else if (!config.validator(value)) {
            errors.push({
                variable: key,
                message: `Invalid value for ${key}: ${config.errorMessage}`,
                description: config.description
            });
        }
    }

    // Check optional variables
    for (const [key, config] of Object.entries(OPTIONAL_VARIABLES)) {
        const value = process.env[key];

        if (value && !config.validator(value)) {
            warnings.push({
                variable: key,
                message: `Invalid value for ${key}: ${config.errorMessage}`
            });
        }

        // Set defaults for missing optional variables
        if (!value && config.default !== undefined) {
            process.env[key] = config.default;
        }
    }

    // Additional cross-validation checks
    const nodeEnv = process.env.NODE_ENV || 'development';
    const envTier = process.env.ENV_TIER || 'local';

    // Warn about mismatched environments
    if (nodeEnv === 'production' && envTier !== 'production') {
        warnings.push({
            variable: 'ENV_TIER',
            message: `NODE_ENV is 'production' but ENV_TIER is '${envTier}'. Consider aligning these.`
        });
    }

    // Warn about production without staging validation
    if (envTier === 'production' && process.env.STAGING_VALIDATED !== 'true') {
        warnings.push({
            variable: 'STAGING_VALIDATED',
            message: 'Deploying to production without staging validation flag. This should be set by CI/CD.'
        });
    }

    // Check for common naming mistakes (the issue that caused our crash)
    const commonMistakes = [
        { wrong: 'SUPABASE_SERVICE_KEY', correct: 'SUPABASE_SERVICE_ROLE_KEY' },
        { wrong: 'SUPABASE_KEY', correct: 'SUPABASE_ANON_KEY' },
        { wrong: 'APPLE_TEAM', correct: 'APPLE_TEAM_ID' },
        { wrong: 'APNS_ID', correct: 'APNS_KEY_ID' }
    ];

    for (const { wrong, correct } of commonMistakes) {
        if (process.env[wrong] && !process.env[correct]) {
            warnings.push({
                variable: wrong,
                message: `Found ${wrong} but the correct variable name is ${correct}. This might cause runtime errors.`
            });
        }
    }

    return {
        isValid: errors.length === 0,
        errors,
        warnings
    };
}

/**
 * Validate environment variables and exit if critical errors are found
 * Call this at server startup
 */
export function validateAndExit(): void {
    const result = validateEnvironmentVariables();

    // Log warnings
    for (const warning of result.warnings) {
        logger.warn(`[EnvValidator] ⚠️ ${warning.message}`, { variable: warning.variable });
    }

    // If there are errors, log them and exit
    if (!result.isValid) {
        logger.error('[EnvValidator] ❌ Environment validation failed!');
        logger.error('[EnvValidator] Missing or invalid environment variables:');

        for (const error of result.errors) {
            logger.error(`[EnvValidator]   • ${error.variable}: ${error.description}`);
            logger.error(`[EnvValidator]     Error: ${error.message}`);
        }

        logger.error('[EnvValidator] 🔧 How to fix:');
        logger.error('[EnvValidator]   1. Check your .env file for missing variables');
        logger.error('[EnvValidator]   2. For Railway: Check your environment variables in the dashboard');
        logger.error('[EnvValidator]   3. Ensure variable names match exactly (case-sensitive)');
        logger.error('[EnvValidator]   4. Common issue: SUPABASE_SERVICE_KEY should be SUPABASE_SERVICE_ROLE_KEY');

        // Exit with error code
        process.exit(1);
    }

    // Success
    logger.info('[EnvValidator] ✅ Environment validation passed', {
        nodeEnv: process.env.NODE_ENV,
        envTier: process.env.ENV_TIER,
        port: process.env.PORT
    });
}

/**
 * Get a summary of the current environment configuration
 * Useful for health checks and debugging
 */
export function getEnvironmentSummary(): Record<string, any> {
    const result = validateEnvironmentVariables();

    return {
        isValid: result.isValid,
        nodeEnv: process.env.NODE_ENV,
        envTier: process.env.ENV_TIER,
        port: process.env.PORT,
        errors: result.errors.length,
        warnings: result.warnings.length,
        requiredVariables: Object.keys(REQUIRED_VARIABLES).reduce((acc, key) => {
            acc[key] = process.env[key] ? '✅ Set' : '❌ Missing';
            return acc;
        }, {} as Record<string, string>),
        optionalVariables: Object.keys(OPTIONAL_VARIABLES).reduce((acc, key) => {
            acc[key] = process.env[key] || `(default: ${OPTIONAL_VARIABLES[key as keyof typeof OPTIONAL_VARIABLES].default})`;
            return acc;
        }, {} as Record<string, string>)
    };
}

export default {
    validateEnvironmentVariables,
    validateAndExit,
    getEnvironmentSummary
};