import { Router, Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { supabaseUrl, supabaseServiceRoleKey, supabaseAnonKey } from '../db/supabase';
import { GoogleGenerativeAI } from '@google/generative-ai';
import axios from 'axios';
import logger from '../utils/logger';

const router = Router();

interface HealthStatus {
    healthy: boolean;
    message?: string;
    details?: any;
}

interface ShareExtensionHealth {
    overall: 'healthy' | 'degraded' | 'unhealthy';
    timestamp: string;
    services: {
        database: HealthStatus;
        gemini: HealthStatus;
        storage: HealthStatus;
        rapidapi: HealthStatus;
    };
}

/**
 * GET /health/share-extension
 * Validates all dependencies required for Share Extension to function
 */
router.get('/share-extension', async (req: Request, res: Response) => {
    const health: ShareExtensionHealth = {
        overall: 'healthy',
        timestamp: new Date().toISOString(),
        services: {
            database: { healthy: false },
            gemini: { healthy: false },
            storage: { healthy: false },
            rapidapi: { healthy: false }
        }
    };

    // 1. Check Database Connection
    try {
        const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);
        const { data, error } = await supabase.from('recipes').select('id').limit(1);

        if (error) throw error;

        health.services.database = {
            healthy: true,
            message: 'Database connection successful'
        };
    } catch (error: any) {
        health.services.database = {
            healthy: false,
            message: 'Database connection failed',
            details: error.message
        };
        health.overall = 'unhealthy';
    }

    // 2. Check Gemini API
    try {
        const apiKey = process.env.GEMINI_API_KEY;
        if (!apiKey) throw new Error('GEMINI_API_KEY not configured');

        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

        // Simple ping test
        const result = await model.generateContent(['test']);

        health.services.gemini = {
            healthy: true,
            message: 'Gemini API accessible'
        };
    } catch (error: any) {
        health.services.gemini = {
            healthy: false,
            message: 'Gemini API failed',
            details: error.message
        };
        health.overall = 'degraded';
    }

    // 3. Check Supabase Storage
    try {
        const supabase = createClient(supabaseUrl, supabaseAnonKey);
        const { data, error } = await supabase.storage.from('recipe-thumbnails').list('', { limit: 1 });

        if (error) throw error;

        health.services.storage = {
            healthy: true,
            message: 'Supabase Storage accessible'
        };
    } catch (error: any) {
        health.services.storage = {
            healthy: false,
            message: 'Storage connection failed',
            details: error.message
        };
        health.overall = 'degraded';
    }

    // 4. Check RapidAPI (Video Downloader)
    try {
        const rapidApiKey = process.env.RAPIDAPI_KEY;
        if (!rapidApiKey) throw new Error('RAPIDAPI_KEY not configured');

        // Just check if the key is valid by hitting a lightweight endpoint
        // We don't actually download anything
        const response = await axios.get('https://social-download-all-in-one.p.rapidapi.com/v1/health', {
            headers: {
                'x-rapidapi-key': rapidApiKey,
                'x-rapidapi-host': 'social-download-all-in-one.p.rapidapi.com'
            },
            timeout: 5000,
            validateStatus: (status) => status < 500 // Accept 4xx as "service is running"
        });

        health.services.rapidapi = {
            healthy: true,
            message: 'RapidAPI accessible'
        };
    } catch (error: any) {
        health.services.rapidapi = {
            healthy: false,
            message: 'RapidAPI connection failed',
            details: error.message
        };
        health.overall = 'degraded';
    }

    // Determine overall status
    const unhealthyCount = Object.values(health.services).filter(s => !s.healthy).length;
    if (unhealthyCount === 0) {
        health.overall = 'healthy';
    } else if (unhealthyCount >= 2) {
        health.overall = 'unhealthy';
    } else {
        health.overall = 'degraded';
    }

    const statusCode = health.overall === 'healthy' ? 200 : health.overall === 'degraded' ? 200 : 503;

    logger.info(`[HealthCheck] Share Extension health: ${health.overall}`);

    res.status(statusCode).json(health);
});

export default router;
