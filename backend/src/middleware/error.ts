import { Request, Response, NextFunction } from 'express';
import logger from '../utils/logger';

export interface AppError extends Error {
    statusCode?: number;
    isOperational?: boolean;
}

export const errorHandler = (
    err: AppError,
    req: Request,
    res: Response,
    next: NextFunction
) => {
    const statusCode = err.statusCode || 500;
    const message = err.message || 'Internal Server Error';

    // Log the error
    logger.error(`${req.method} ${req.originalUrl} - ${statusCode} - ${message}`, {
        stack: err.stack,
        requestId: req.headers['x-request-id']
    });

    // Respond to user
    res.status(statusCode).json({
        success: false,
        error: message,
        stack: process.env.NODE_ENV === 'development' ? err.stack : undefined
    });
};

export const wrapAsync = (fn: any) => {
    return (req: any, res: Response, next: NextFunction) => {
        fn(req, res, next).catch(next);
    };
};
