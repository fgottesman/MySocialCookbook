/**
 * Correlation Context Middleware
 * Automatically sets correlation context for each request
 * Makes debugging easier by tracking requests across logs
 */

import { Request, Response, NextFunction } from 'express';
import { setCorrelationContext, addToCorrelationContext } from '../utils/logger';

/**
 * Middleware to set correlation context for the request
 * Uses the existing request ID and adds user information if available
 */
export function correlationContextMiddleware(req: Request, res: Response, next: NextFunction) {
    // Get request ID (already set by request ID middleware in index.ts)
    const correlationId = req.headers['x-request-id'] as string;

    // Build correlation data
    const correlationData: Record<string, any> = {
        correlationId,
        method: req.method,
        path: req.path,
        ip: req.ip
    };

    // Add user ID if authenticated (set by auth middleware)
    const user = (req as any).user;
    if (user?.id) {
        correlationData.userId = user.id;
    }

    // Run the rest of the request in correlation context
    setCorrelationContext(correlationData, () => {
        // Continue with the request
        next();
    });
}

export default correlationContextMiddleware;
