import { getCurrentTier, canDeployToTier, getTierMetadata, EnvTier } from '../src/utils/validateEnvTiers';

/**
 * Unit Tests for Environment Tier Validation
 * Run with: npm test -- --testPathPattern=validateEnvTiers
 */

// Mock the logger to avoid console noise
jest.mock('../src/utils/logger', () => ({
    __esModule: true,
    default: {
        warn: jest.fn(),
        info: jest.fn(),
        error: jest.fn(),
        debug: jest.fn(),
    }
}));

describe('validateEnvTiers', () => {
    const originalEnv = process.env;

    beforeEach(() => {
        jest.resetModules();
        process.env = { ...originalEnv };
    });

    afterAll(() => {
        process.env = originalEnv;
    });

    describe('getCurrentTier', () => {
        test('returns "local" when ENV_TIER is not set', () => {
            delete process.env.ENV_TIER;
            expect(getCurrentTier()).toBe('local');
        });

        test('returns "local" when ENV_TIER is empty string', () => {
            process.env.ENV_TIER = '';
            expect(getCurrentTier()).toBe('local');
        });

        test('returns "local" when ENV_TIER has only whitespace', () => {
            process.env.ENV_TIER = '   ';
            expect(getCurrentTier()).toBe('local');
        });

        test('returns correct tier for valid values', () => {
            process.env.ENV_TIER = 'local';
            expect(getCurrentTier()).toBe('local');

            process.env.ENV_TIER = 'staging';
            expect(getCurrentTier()).toBe('staging');

            process.env.ENV_TIER = 'production';
            expect(getCurrentTier()).toBe('production');
        });

        test('handles case insensitivity', () => {
            process.env.ENV_TIER = 'PRODUCTION';
            expect(getCurrentTier()).toBe('production');

            process.env.ENV_TIER = 'Staging';
            expect(getCurrentTier()).toBe('staging');
        });

        test('trims whitespace from ENV_TIER', () => {
            process.env.ENV_TIER = '  staging  ';
            expect(getCurrentTier()).toBe('staging');
        });

        test('returns "local" for invalid tier values', () => {
            process.env.ENV_TIER = 'invalid';
            expect(getCurrentTier()).toBe('local');

            process.env.ENV_TIER = 'prod';  // Not a valid value
            expect(getCurrentTier()).toBe('local');
        });
    });

    describe('canDeployToTier', () => {
        test('always returns true for local tier', () => {
            delete process.env.STAGING_VALIDATED;
            expect(canDeployToTier('local')).toBe(true);
        });

        test('always returns true for staging tier', () => {
            delete process.env.STAGING_VALIDATED;
            expect(canDeployToTier('staging')).toBe(true);
        });

        test('returns true for production when STAGING_VALIDATED is true', () => {
            process.env.STAGING_VALIDATED = 'true';
            expect(canDeployToTier('production')).toBe(true);
        });

        test('returns false for production when STAGING_VALIDATED is not set', () => {
            delete process.env.STAGING_VALIDATED;
            expect(canDeployToTier('production')).toBe(false);
        });

        test('returns false for production when STAGING_VALIDATED is not exactly "true"', () => {
            process.env.STAGING_VALIDATED = 'TRUE';  // Case matters
            expect(canDeployToTier('production')).toBe(false);

            process.env.STAGING_VALIDATED = '1';
            expect(canDeployToTier('production')).toBe(false);

            process.env.STAGING_VALIDATED = 'yes';
            expect(canDeployToTier('production')).toBe(false);
        });
    });

    describe('getTierMetadata', () => {
        test('returns correct metadata for local tier', () => {
            process.env.ENV_TIER = 'local';
            const metadata = getTierMetadata();
            expect(metadata).toEqual({
                tier: 'local',
                tierIndex: 0,
                isProduction: false
            });
        });

        test('returns correct metadata for staging tier', () => {
            process.env.ENV_TIER = 'staging';
            const metadata = getTierMetadata();
            expect(metadata).toEqual({
                tier: 'staging',
                tierIndex: 1,
                isProduction: false
            });
        });

        test('returns correct metadata for production tier', () => {
            process.env.ENV_TIER = 'production';
            const metadata = getTierMetadata();
            expect(metadata).toEqual({
                tier: 'production',
                tierIndex: 2,
                isProduction: true
            });
        });
    });
});
