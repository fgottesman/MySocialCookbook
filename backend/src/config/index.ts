/**
 * Configuration Management
 * Centralized configuration for all application settings
 * Single source of truth for constants and configuration values
 */

export const config = {
    // Server Configuration
    server: {
        port: parseInt(process.env.PORT || '8080'),
        env: process.env.NODE_ENV || 'development',
        tier: process.env.ENV_TIER || 'local',
        requestTimeout: 30000, // 30 seconds
        jsonBodyLimit: '50mb'
    },

    // Rate Limiting
    rateLimit: {
        ai: {
            windowMs: 15 * 60 * 1000, // 15 minutes
            max: 10 // 10 requests per window per IP
        },
        feed: {
            windowMs: 1 * 60 * 1000, // 1 minute
            max: 30 // 30 requests per minute
        },
        default: {
            windowMs: 15 * 60 * 1000,
            max: 100
        }
    },

    // Database Configuration
    database: {
        supabase: {
            url: process.env.SUPABASE_URL || '',
            anonKey: process.env.SUPABASE_ANON_KEY || '',
            serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || ''
        },
        connectionTimeout: 5000,
        queryTimeout: 10000
    },

    // AI Services
    ai: {
        gemini: {
            apiKey: process.env.GEMINI_API_KEY || '',
            defaultModel: 'gemini-2.0-flash-exp',
            recipeEngine: 'gemini-2.0-flash-exp',
            imageGeneration: 'gemini-2.0-flash-exp',
            tts: 'gemini-2.0-flash-exp',
            timeout: 60000 // 60 seconds for AI requests
        },
        rapidApi: {
            key: process.env.RAPIDAPI_KEY || '',
            timeout: 30000
        }
    },

    // Push Notifications
    apns: {
        key: process.env.APNS_KEY || '',
        keyId: process.env.APNS_KEY_ID || '',
        teamId: process.env.APPLE_TEAM_ID || '',
        env: (process.env.APNS_ENV as 'production' | 'development') ||
             (process.env.NODE_ENV === 'production' ? 'production' : 'development'),
        bundleId: 'com.clipcook.app'
    },

    // Subscription & Paywall
    subscription: {
        revenueCat: {
            webhookSecret: process.env.REVENUECAT_WEBHOOK_SECRET || ''
        },
        defaults: {
            freeRecipeCredits: 2,
            monthlyRecipeCredits: 5,
            firstRecipeOfferDuration: 3600 // 1 hour in seconds
        }
    },

    // Recipe Processing
    recipe: {
        maxVersionRetries: 3,
        versionRetryDelay: 100, // milliseconds
        maxTitleLength: 200,
        maxDescriptionLength: 1000,
        maxChefNoteLength: 500,
        maxIngredients: 50,
        maxInstructions: 50,
        preComputeSteps: true
    },

    // Storage
    storage: {
        thumbnailBucket: 'recipe-thumbnails',
        maxThumbnailSize: 5 * 1024 * 1024, // 5MB
        allowedImageTypes: ['image/jpeg', 'image/png', 'image/webp'],
        allowedAudioTypes: ['audio/mpeg', 'audio/webm', 'audio/wav']
    },

    // WebSocket (Live Voice)
    websocket: {
        heartbeatInterval: 30000, // 30 seconds
        connectionTimeout: 60000 // 60 seconds
    },

    // Logging
    logging: {
        level: process.env.NODE_ENV === 'production' ? 'info' : 'debug',
        enableConsole: process.env.NODE_ENV !== 'production',
        enableFile: process.env.NODE_ENV === 'production'
    },

    // Security
    security: {
        corsOrigins: process.env.CORS_ORIGINS?.split(',') || ['*'],
        trustProxy: true,
        helmet: {
            enabled: process.env.NODE_ENV === 'production'
        }
    },

    // Feature Flags (for future use)
    features: {
        enableWebSocketLiveCooking: true,
        enableRecipeRemix: true,
        enableImageGeneration: true,
        enableTTS: true,
        enablePreCompute: true,
        enableFirstRecipeOffer: true
    }
} as const;

// Type-safe config access
export type Config = typeof config;

// Helper to check if running in production
export const isProduction = () => config.server.env === 'production';
export const isDevelopment = () => config.server.env === 'development';
export const isStaging = () => config.server.tier === 'staging';

// Export individual config sections for convenience
export const {
    server: serverConfig,
    rateLimit: rateLimitConfig,
    database: databaseConfig,
    ai: aiConfig,
    apns: apnsConfig,
    subscription: subscriptionConfig,
    recipe: recipeConfig,
    storage: storageConfig,
    websocket: websocketConfig,
    logging: loggingConfig,
    security: securityConfig,
    features: featureFlags
} = config;

export default config;
