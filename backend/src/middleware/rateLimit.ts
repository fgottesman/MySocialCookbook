import rateLimit from 'express-rate-limit';
import { AuthRequest } from './auth';

// Standard rate limit for most API endpoints
export const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Limit each IP to 100 requests per windowMs
    standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
    legacyHeaders: false, // Disable the `X-RateLimit-*` headers
    message: {
        error: 'Too many requests, please try again after 15 minutes'
    },
    keyGenerator: (req) => {
        // Use user ID if authenticated, otherwise fallback to IP
        const authReq = req as AuthRequest;
        return authReq.user?.id || req.ip || 'anonymous';
    }
});

// Stricter rate limit for expensive AI endpoints (Gemini)
export const aiLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 20, // Limit each IP or User to 20 AI requests per hour
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        error: 'You have reached the hourly limit for AI cooking assistants. Please try again soon!'
    },
    keyGenerator: (req) => {
        const authReq = req as AuthRequest;
        return authReq.user?.id || req.ip || 'anonymous';
    }
});
