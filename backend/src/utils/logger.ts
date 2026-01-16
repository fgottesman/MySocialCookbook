import winston from 'winston';
import { AsyncLocalStorage } from 'async_hooks';

const { combine, timestamp, printf, colorize, errors, json } = winston.format;

// AsyncLocalStorage for correlation context
const correlationContext = new AsyncLocalStorage<Map<string, any>>();

// Enhanced log format with correlation IDs and structured data
const logFormat = printf(({ level, message, timestamp, stack, ...metadata }) => {
    // Get correlation context if available
    const context = correlationContext.getStore();
    const correlationId = context?.get('correlationId') || metadata.correlationId;
    const userId = context?.get('userId') || metadata.userId;

    // Build structured log message
    const parts = [timestamp, `[${level}]`];

    if (correlationId) {
        parts.push(`[${correlationId}]`);
    }

    if (userId) {
        parts.push(`[user:${userId}]`);
    }

    parts.push(stack || message);

    // Add metadata if present
    if (Object.keys(metadata).length > 0) {
        parts.push(JSON.stringify(metadata));
    }

    return parts.join(' ');
});

const logger = winston.createLogger({
    level: process.env.NODE_ENV === 'production' ? 'info' : 'debug',
    format: combine(
        timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
        errors({ stack: true }),
        logFormat
    ),
    transports: [
        new winston.transports.Console({
            format: combine(
                colorize(),
                logFormat
            )
        })
    ]
});

// Production logging to files
if (process.env.NODE_ENV === 'production') {
    logger.add(new winston.transports.File({
        filename: 'error.log',
        level: 'error',
        format: combine(
            timestamp(),
            errors({ stack: true }),
            json()
        )
    }));

    logger.add(new winston.transports.File({
        filename: 'combined.log',
        format: combine(
            timestamp(),
            json()
        )
    }));
}

/**
 * Set correlation context for the current async flow
 * This allows all logs within a request to have the same correlation ID
 */
function setCorrelationContext(data: Record<string, any>, callback: () => any) {
    const store = new Map(Object.entries(data));
    return correlationContext.run(store, callback);
}

/**
 * Get current correlation context
 */
function getCorrelationContext(): Record<string, any> | undefined {
    const context = correlationContext.getStore();
    if (!context) return undefined;

    return Object.fromEntries(context.entries());
}

/**
 * Add data to current correlation context
 */
function addToCorrelationContext(key: string, value: any) {
    const context = correlationContext.getStore();
    if (context) {
        context.set(key, value);
    }
}

/**
 * Enhanced logger with correlation context support
 * Backward compatible with existing logger usage
 */
const enhancedLogger = {
    ...logger,

    // Override log methods to include correlation context
    info: (message: string, meta?: any) => {
        const context = getCorrelationContext();
        logger.info(message, { ...context, ...meta });
    },

    error: (message: string, meta?: any) => {
        const context = getCorrelationContext();
        logger.error(message, { ...context, ...meta });
    },

    warn: (message: string, meta?: any) => {
        const context = getCorrelationContext();
        logger.warn(message, { ...context, ...meta });
    },

    debug: (message: string, meta?: any) => {
        const context = getCorrelationContext();
        logger.debug(message, { ...context, ...meta });
    }
};

// Export correlation context functions
export {
    setCorrelationContext,
    getCorrelationContext,
    addToCorrelationContext
};

export default enhancedLogger;
