/**
 * Subscription Routes
 * API endpoints for subscription management, config, and entitlements.
 */

import { Router, Request, Response } from 'express';
import {
    loadEntitlements,
    claimMonthlyCredits,
    markFirstRecipeOfferShown,
    markFirstRecipeOfferClaimed,
    updateSubscriptionStatus
} from '../middleware/subscriptionMiddleware';
import { createClient } from '@supabase/supabase-js';
import logger from '../utils/logger';

const router = Router();

const supabaseAdmin = createClient(
    process.env.SUPABASE_URL || '',
    process.env.SUPABASE_SERVICE_ROLE_KEY || ''
);

// ============================================
// PUBLIC ROUTES
// ============================================

/**
 * GET /subscription/config
 * Returns the app configuration (for client-side use)
 */
router.get('/config', async (req: Request, res: Response) => {
    try {
        const { data, error } = await supabaseAdmin
            .from('app_config')
            .select('value')
            .eq('key', 'main')
            .single();

        if (error) {
            logger.error('Failed to fetch app config', { error });
            return res.status(500).json({ error: 'Failed to fetch config' });
        }

        res.json(data.value);
    } catch (error) {
        logger.error('Error in /subscription/config', { error });
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ============================================
// AUTHENTICATED ROUTES
// ============================================

/**
 * GET /subscription/status
 * Returns the current user's subscription status and entitlements
 */
router.get('/status', loadEntitlements, async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user?.id;

        if (!userId) {
            return res.status(401).json({ error: 'Authentication required' });
        }

        // Check for monthly credits to claim
        let monthlyCreditsAdded = 0;
        if (req.entitlements && !req.entitlements.isPro && req.entitlements.monthlyCreditsAvailable > 0) {
            monthlyCreditsAdded = await claimMonthlyCredits(userId);
            if (monthlyCreditsAdded > 0) {
                // Update the entitlements object with new credits
                req.entitlements.recipeCreditsRemaining += monthlyCreditsAdded;
                req.entitlements.monthlyCreditsAvailable = 0;
            }
        }

        res.json({
            ...req.entitlements,
            monthlyCreditsAdded, // Let client know if credits were just added
            config: req.appConfig
        });
    } catch (error) {
        logger.error('Error in /subscription/status', { error });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /subscription/first-recipe-offer/shown
 * Mark that the first recipe offer has been shown to the user
 */
router.post('/first-recipe-offer/shown', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user?.id;

        if (!userId) {
            return res.status(401).json({ error: 'Authentication required' });
        }

        const durationSeconds = req.body.durationSeconds || 3600;
        await markFirstRecipeOfferShown(userId, durationSeconds);

        res.json({ success: true });
    } catch (error) {
        logger.error('Error in /subscription/first-recipe-offer/shown', { error });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /subscription/first-recipe-offer/claimed
 * Mark that the user claimed the first recipe offer
 */
router.post('/first-recipe-offer/claimed', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user?.id;

        if (!userId) {
            return res.status(401).json({ error: 'Authentication required' });
        }

        await markFirstRecipeOfferClaimed(userId);

        res.json({ success: true });
    } catch (error) {
        logger.error('Error in /subscription/first-recipe-offer/claimed', { error });
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ============================================
// REVENUECAT WEBHOOK
// ============================================

/**
 * POST /subscription/webhook/revenuecat
 * Handles RevenueCat subscription events
 * 
 * Events: INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, etc.
 */
router.post('/webhook/revenuecat', async (req: Request, res: Response) => {
    try {
        const event = req.body;

        // Validate webhook (in production, verify signature)
        if (!event || !event.event) {
            return res.status(400).json({ error: 'Invalid webhook payload' });
        }

        logger.info('RevenueCat webhook received', {
            type: event.event.type,
            userId: event.event.app_user_id
        });

        const userId = event.event.app_user_id;
        const eventType = event.event.type;
        const productId = event.event.product_id;
        const expirationDate = event.event.expiration_at_ms
            ? new Date(event.event.expiration_at_ms)
            : undefined;

        switch (eventType) {
            case 'INITIAL_PURCHASE':
            case 'RENEWAL':
            case 'PRODUCT_CHANGE':
                await updateSubscriptionStatus(userId, 'pro', productId, expirationDate);
                break;

            case 'CANCELLATION':
            case 'EXPIRATION':
                await updateSubscriptionStatus(userId, 'expired', productId);
                break;

            case 'UNCANCELLATION':
                await updateSubscriptionStatus(userId, 'pro', productId, expirationDate);
                break;

            default:
                logger.info('Unhandled RevenueCat event type', { eventType });
        }

        res.json({ success: true });
    } catch (error) {
        logger.error('Error processing RevenueCat webhook', { error });
        res.status(500).json({ error: 'Internal server error' });
    }
});

export default router;
