import logger from './logger';

export interface RetryOptions {
    maxRetries?: number;
    initialDelay?: number;
    maxDelay?: number;
    factor?: number;
}

export async function withRetry<T>(
    fn: () => Promise<T>,
    options: RetryOptions = {},
    context: string = 'Operation'
): Promise<T> {
    const {
        maxRetries = 3,
        initialDelay = 1000,
        maxDelay = 10000,
        factor = 2
    } = options;

    let attempt = 0;
    let delay = initialDelay;

    while (attempt <= maxRetries) {
        try {
            return await fn();
        } catch (error: any) {
            attempt++;
            if (attempt > maxRetries) {
                logger.error(`${context} failed after ${maxRetries} retries: ${error.message}`);
                throw error;
            }

            logger.warn(`${context} attempt ${attempt} failed. Retrying in ${delay}ms...`, { error: error.message });

            await new Promise(resolve => setTimeout(resolve, delay));
            delay = Math.min(delay * factor, maxDelay);
        }
    }

    throw new Error(`${context} failed unexpectedly`);
}
