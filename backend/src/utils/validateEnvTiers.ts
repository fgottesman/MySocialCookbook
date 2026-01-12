import logger from './logger';

/**
 * Environment Tier Validation System
 * 
 * ⚠️ NOT INTEGRATED INTO SERVER STARTUP YET
 * This module provides infrastructure for the GitHub Actions tier-deploy workflow.
 * Integration into server startup will be added after staging environment is created.
 * 
 * Tier progression: LOCAL (dev) → STAGING → PRODUCTION
 */

export type EnvTier = 'local' | 'staging' | 'production';

const TIER_ORDER: EnvTier[] = ['local', 'staging', 'production'];
const TIER_INDEX: Record<EnvTier, number> = { local: 0, staging: 1, production: 2 };

/**
 * Get the current environment tier from ENV_TIER variable
 * Defaults to 'local' for development
 */
export function getCurrentTier(): EnvTier {
    const tier = (process.env.ENV_TIER || '').toLowerCase().trim() as EnvTier;
    if (tier && TIER_ORDER.includes(tier)) {
        return tier;
    }
    // Default to 'local' for development environments
    return 'local';
}

/**
 * Check if the current tier can be deployed to
 */
export function canDeployToTier(tier: EnvTier): boolean {
    // Local and staging are always allowed
    if (tier === 'local' || tier === 'staging') {
        return true;
    }

    // Production requires staging validation (enforced via GitHub Actions)
    const stagingValidated = process.env.STAGING_VALIDATED === 'true';

    if (!stagingValidated) {
        logger.warn('[TierValidation] ⚠️ Production deploy without staging validation');
    }

    return stagingValidated;
}

/**
 * Get metadata about the current tier for health checks
 */
export function getTierMetadata(): { tier: EnvTier; tierIndex: number; isProduction: boolean } {
    const tier = getCurrentTier();
    return {
        tier,
        tierIndex: TIER_INDEX[tier],
        isProduction: tier === 'production'
    };
}
// Trigger tier validation test
