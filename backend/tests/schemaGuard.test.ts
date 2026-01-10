import { checkSchema } from '../src/utils/schemaGuard';
import { createClient } from '@supabase/supabase-js';

/**
 * Unit Tests for Schema Guard
 * 
 * These tests validate schema checking logic without requiring a live database.
 * The probe-based approach selects from tables with explicit column names,
 * and Supabase returns errors if columns don't exist.
 * 
 * Run with: npm run test:unit
 */

// Mock Supabase client
jest.mock('@supabase/supabase-js');

describe('Schema Guard', () => {
    let mockSupabase: any;

    beforeEach(() => {
        // Reset mocks before each test
        jest.clearAllMocks();

        // Create mock Supabase client for probe-based validation
        mockSupabase = {
            from: jest.fn().mockReturnThis(),
            select: jest.fn().mockReturnThis(),
            limit: jest.fn().mockReturnThis(),
        };

        (createClient as jest.Mock).mockReturnValue(mockSupabase);
    });

    test('should pass when all required columns exist', async () => {
        // Mock successful probe - query succeeds means all columns exist
        mockSupabase.limit.mockResolvedValue({
            data: [{ id: 'test', title: 'Test Recipe' }],
            error: null
        });

        await expect(checkSchema()).resolves.not.toThrow();
    });

    test('should throw error when required column is missing', async () => {
        // Mock error when column doesn't exist
        mockSupabase.limit.mockResolvedValue({
            data: null,
            error: {
                message: 'column "difficulty" does not exist'
            }
        });

        await expect(checkSchema()).rejects.toThrow(/schema/i);
    });

    test('should throw error when table does not exist', async () => {
        // Mock error when table doesn't exist
        mockSupabase.limit.mockResolvedValue({
            data: null,
            error: {
                message: 'relation "recipes" does not exist'
            }
        });

        await expect(checkSchema()).rejects.toThrow(/does not exist/i);
    });

    test('should throw error on database query failure', async () => {
        // Mock database error
        mockSupabase.limit.mockResolvedValue({
            data: null,
            error: { message: 'Connection timeout' }
        });

        await expect(checkSchema()).rejects.toThrow();
    });

    test('should validate all required tables', async () => {
        // Mock successful responses for both tables
        mockSupabase.limit.mockResolvedValue({
            data: [],
            error: null
        });

        await checkSchema();

        // Verify both tables were probed
        expect(mockSupabase.from).toHaveBeenCalledWith('recipes');
        expect(mockSupabase.from).toHaveBeenCalledWith('recipe_versions');
    });

    test('should bypass validation when SKIP_SCHEMA_CHECK is true', async () => {
        // Set environment variable
        const originalEnv = process.env.SKIP_SCHEMA_CHECK;
        process.env.SKIP_SCHEMA_CHECK = 'true';

        // Should not throw even if we don't set up mocks
        await expect(checkSchema()).resolves.not.toThrow();

        // Restore
        process.env.SKIP_SCHEMA_CHECK = originalEnv;
    });
});
