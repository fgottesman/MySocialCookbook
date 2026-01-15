/**
 * Subscription Middleware
 * Handles entitlement checking and credits tracking for the paywall system.
 * 
 * IMPORTANT: All checks respect the `paywallEnabled` kill switch from app_config.
 * When paywallEnabled is false, all users have unlimited access.
 */

import { Request, Response, NextFunction } from 'express';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import logger from '../utils/logger';

// Admin client for server-side operations
const supabaseAdmin = createClient(
    process.env.SUPABASE_URL || '',
    process.env.SUPABASE_SERVICE_ROLE_KEY || ''
);

// ============================================
// TYPES
// ============================================

export interface AppConfig {
    paywallEnabled: boolean;
    entitlements: {
        starterRecipeCredits: number;
        monthlyFreeCredits: number;
        starterRemixCredits: number;
        voicePreviewSeconds: number;
    };
    offers: {
        firstRecipeOfferEnabled: boolean;
        firstRecipeOfferDurationSeconds: number;
        firstRecipeOfferDiscountPercent: number;
    };
    pricing: {
        monthlyPrice: string;
        annualPrice: string;
        annualSavings: string;
    };
}

export interface UserEntitlements {
    status: 'free' | 'pro' | 'expired';
    isPro: boolean;

    // Recipe credits
    recipeCreditsUsed: number;
    recipeCreditsRemaining: number;
    canImportRecipe: boolean;

    // Voice
    voicePreviewSeconds: number; // -1 = unlimited
    canUseVoiceUnlimited: boolean;

    // Remix
    remixCreditsUsed: number;
    remixCreditsRemaining: number;
    canRemix: boolean;

    // Monthly credits
    monthlyCreditsAvailable: number;

    // First recipe offer
    isFirstRecipe: boolean;
    showFirstRecipeOffer: boolean;
}

// Extend Express Request
declare global {
    namespace Express {
        interface Request {
            entitlements?: UserEntitlements;
            appConfig?: AppConfig;
        }
    }
}

// ============================================
// CONFIG CACHE
// ============================================

let configCache: AppConfig | null = null;
let configCacheTime = 0;
const CONFIG_CACHE_TTL = 60 * 1000; // 1 minute

const DEFAULT_CONFIG: AppConfig = {
    paywallEnabled: false, // Kill switch OFF by default
    entitlements: {
        starterRecipeCredits: 5,
        monthlyFreeCredits: 3,
        starterRemixCredits: 10,
        voicePreviewSeconds: 60
    },
    offers: {
        firstRecipeOfferEnabled: true,
        firstRecipeOfferDurationSeconds: 3600,
        firstRecipeOfferDiscountPercent: 50
    },
    pricing: {
        monthlyPrice: '$3.99',
        annualPrice: '$21.99',
        annualSavings: 'Save 45%'
    }
};

async function getAppConfig(): Promise<AppConfig> {
    const now = Date.now();

    // Return cache if valid
    if (configCache && (now - configCacheTime) < CONFIG_CACHE_TTL) {
        return configCache;
    }

    try {
        const { data, error } = await supabaseAdmin
            .from('app_config')
            .select('value')
            .eq('key', 'main')
            .single();

        if (error || !data) {
            logger.warn('Failed to fetch app config, using defaults', { error });
            return DEFAULT_CONFIG;
        }

        configCache = data.value as AppConfig;
        configCacheTime = now;
        return configCache;
    } catch (error) {
        logger.error('Error fetching app config', { error });
        return DEFAULT_CONFIG;
    }
}

// ============================================
// MIDDLEWARE
// ============================================

/**
 * Load user entitlements and app config.
 * Attaches `req.entitlements` and `req.appConfig` to the request.
 */
export async function loadEntitlements(req: Request, res: Response, next: NextFunction) {
    try {
        const config = await getAppConfig();
        req.appConfig = config;

        const userId = (req as any).user?.id;

        // If paywall is disabled, everyone gets unlimited access
        if (!config.paywallEnabled) {
            req.entitlements = {
                status: 'pro', // Treat everyone as pro when paywall disabled
                isPro: true,
                recipeCreditsUsed: 0,
                recipeCreditsRemaining: 999,
                canImportRecipe: true,
                voicePreviewSeconds: -1,
                canUseVoiceUnlimited: true,
                remixCreditsUsed: 0,
                remixCreditsRemaining: 999,
                canRemix: true,
                monthlyCreditsAvailable: 0,
                isFirstRecipe: false,
                showFirstRecipeOffer: false
            };
            return next();
        }

        // No user = anonymous, give default free entitlements
        if (!userId) {
            req.entitlements = {
                status: 'free',
                isPro: false,
                recipeCreditsUsed: 0,
                recipeCreditsRemaining: config.entitlements.starterRecipeCredits,
                canImportRecipe: true,
                voicePreviewSeconds: config.entitlements.voicePreviewSeconds,
                canUseVoiceUnlimited: false,
                remixCreditsUsed: 0,
                remixCreditsRemaining: config.entitlements.starterRemixCredits,
                canRemix: true,
                monthlyCreditsAvailable: 0,
                isFirstRecipe: true,
                showFirstRecipeOffer: false
            };
            return next();
        }

        // Fetch user entitlements from database
        const { data: userEntitlements, error } = await supabaseAdmin
            .from('user_entitlements')
            .select('*')
            .eq('id', userId)
            .single();

        if (error && error.code !== 'PGRST116') { // PGRST116 = not found
            logger.error('Error fetching user entitlements', { error, userId });
        }

        // If no entitlements record, create one
        if (!userEntitlements) {
            await supabaseAdmin
                .from('user_entitlements')
                .insert({ id: userId })
                .single();
        }

        const ue = userEntitlements || {
            subscription_status: 'free',
            recipe_credits_used: 0,
            remix_credits_used: 0,
            first_recipe_at: null,
            monthly_credits_claimed_at: null
        };

        const isPro = ue.subscription_status === 'pro';
        const recipeCreditsUsed = ue.recipe_credits_used || 0;
        const remixCreditsUsed = ue.remix_credits_used || 0;

        // Calculate monthly credits
        let monthlyCreditsAvailable = 0;
        const lastClaim = ue.monthly_credits_claimed_at ? new Date(ue.monthly_credits_claimed_at) : null;
        const startOfMonth = new Date();
        startOfMonth.setDate(1);
        startOfMonth.setHours(0, 0, 0, 0);

        if (!lastClaim || lastClaim < startOfMonth) {
            monthlyCreditsAvailable = config.entitlements.monthlyFreeCredits;
        }

        // Calculate remaining credits (starter + monthly bonus)
        const totalRecipeCredits = config.entitlements.starterRecipeCredits + monthlyCreditsAvailable;
        const recipeCreditsRemaining = Math.max(0, totalRecipeCredits - recipeCreditsUsed);
        const remixCreditsRemaining = Math.max(0, config.entitlements.starterRemixCredits - remixCreditsUsed);

        // First recipe offer logic
        const isFirstRecipe = !ue.first_recipe_at;
        const showFirstRecipeOffer = config.offers.firstRecipeOfferEnabled &&
            !ue.first_recipe_offer_claimed &&
            ue.first_recipe_at && // Has made first recipe
            (!ue.first_recipe_offer_expires_at || new Date(ue.first_recipe_offer_expires_at) > new Date());

        req.entitlements = {
            status: ue.subscription_status as 'free' | 'pro' | 'expired',
            isPro,
            recipeCreditsUsed,
            recipeCreditsRemaining,
            canImportRecipe: isPro || recipeCreditsRemaining > 0,
            voicePreviewSeconds: isPro ? -1 : config.entitlements.voicePreviewSeconds,
            canUseVoiceUnlimited: isPro,
            remixCreditsUsed,
            remixCreditsRemaining,
            canRemix: isPro || remixCreditsRemaining > 0,
            monthlyCreditsAvailable,
            isFirstRecipe,
            showFirstRecipeOffer
        };

        next();
    } catch (error) {
        logger.error('Error in loadEntitlements middleware', { error });
        // On error, allow access (fail open for better UX)
        req.entitlements = {
            status: 'free',
            isPro: false,
            recipeCreditsUsed: 0,
            recipeCreditsRemaining: 5,
            canImportRecipe: true,
            voicePreviewSeconds: 60,
            canUseVoiceUnlimited: false,
            remixCreditsUsed: 0,
            remixCreditsRemaining: 10,
            canRemix: true,
            monthlyCreditsAvailable: 0,
            isFirstRecipe: true,
            showFirstRecipeOffer: false
        };
        next();
    }
}

/**
 * Require recipe credits to proceed.
 * Returns 403 if user has exhausted their credits.
 */
export function requireRecipeCredits(req: Request, res: Response, next: NextFunction) {
    if (!req.entitlements?.canImportRecipe) {
        return res.status(403).json({
            error: 'credits_exhausted',
            code: 'RECIPE_CREDITS_EXHAUSTED',
            message: 'You\'ve used your starter credits. Unlock unlimited imports with Pro.',
            creditsUsed: req.entitlements?.recipeCreditsUsed,
            upgradeUrl: 'clipcook://upgrade'
        });
    }
    next();
}

/**
 * Require remix credits to proceed.
 */
export function requireRemixCredits(req: Request, res: Response, next: NextFunction) {
    if (!req.entitlements?.canRemix) {
        return res.status(403).json({
            error: 'credits_exhausted',
            code: 'REMIX_CREDITS_EXHAUSTED',
            message: 'You\'ve used your remix credits. Unlock unlimited remixing with Pro.',
            creditsUsed: req.entitlements?.remixCreditsUsed,
            upgradeUrl: 'clipcook://upgrade'
        });
    }
    next();
}

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Increment recipe credits used for a user.
 * Call this after successfully creating a recipe.
 */
export async function incrementRecipeCredits(userId: string): Promise<void> {
    try {
        await supabaseAdmin.rpc('increment_recipe_credits', { p_user_id: userId });
    } catch (error) {
        logger.error('Failed to increment recipe credits', { error, userId });
    }
}

/**
 * Increment remix credits used for a user.
 */
export async function incrementRemixCredits(userId: string): Promise<void> {
    try {
        await supabaseAdmin.rpc('increment_remix_credits', { p_user_id: userId });
    } catch (error) {
        logger.error('Failed to increment remix credits', { error, userId });
    }
}

/**
 * Claim monthly credits for a user.
 * Returns the number of credits added (0 if already claimed this month).
 */
export async function claimMonthlyCredits(userId: string): Promise<number> {
    try {
        const { data, error } = await supabaseAdmin.rpc('claim_monthly_credits', { p_user_id: userId });
        if (error) throw error;
        return data as number;
    } catch (error) {
        logger.error('Failed to claim monthly credits', { error, userId });
        return 0;
    }
}

/**
 * Mark first recipe offer as shown for a user.
 */
export async function markFirstRecipeOfferShown(userId: string, expiresInSeconds: number = 3600): Promise<void> {
    try {
        const expiresAt = new Date(Date.now() + expiresInSeconds * 1000);
        await supabaseAdmin
            .from('user_entitlements')
            .update({
                first_recipe_offer_shown_at: new Date().toISOString(),
                first_recipe_offer_expires_at: expiresAt.toISOString(),
                updated_at: new Date().toISOString()
            })
            .eq('id', userId);
    } catch (error) {
        logger.error('Failed to mark first recipe offer shown', { error, userId });
    }
}

/**
 * Mark first recipe offer as claimed.
 */
export async function markFirstRecipeOfferClaimed(userId: string): Promise<void> {
    try {
        await supabaseAdmin
            .from('user_entitlements')
            .update({
                first_recipe_offer_claimed: true,
                upgraded_at: new Date().toISOString(),
                subscription_status: 'pro',
                updated_at: new Date().toISOString()
            })
            .eq('id', userId);
    } catch (error) {
        logger.error('Failed to mark first recipe offer claimed', { error, userId });
    }
}

/**
 * Update subscription status (called from RevenueCat webhook).
 */
export async function updateSubscriptionStatus(
    userId: string,
    status: 'free' | 'pro' | 'expired',
    productId?: string,
    expiresAt?: Date
): Promise<void> {
    try {
        await supabaseAdmin
            .from('user_entitlements')
            .update({
                subscription_status: status,
                subscription_product_id: productId || null,
                subscription_expires_at: expiresAt?.toISOString() || null,
                upgraded_at: status === 'pro' ? new Date().toISOString() : null,
                updated_at: new Date().toISOString()
            })
            .eq('id', userId);
    } catch (error) {
        logger.error('Failed to update subscription status', { error, userId, status });
    }
}
