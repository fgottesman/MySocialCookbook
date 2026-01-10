import { createClient } from '@supabase/supabase-js';
import { supabaseUrl, supabaseServiceRoleKey } from '../db/supabase';
import logger from './logger';

/**
 * Schema Guard: Validates that the database schema matches code expectations
 * This prevents silent failures from schema drift (e.g., missing columns)
 */

interface RequiredColumns {
    [tableName: string]: string[];
}

const REQUIRED_SCHEMA: RequiredColumns = {
    recipes: [
        'id',
        'user_id',
        'title',
        'description',
        'video_url',
        'thumbnail_url',
        'ingredients',
        'instructions',
        'embedding',
        'created_at',
        'chefs_note',
        'is_favorite',
        'parent_recipe_id',
        'source_prompt',
        'source_url',
        'step_preparations',
        'step0_summary',
        'step0_audio_url',
        'difficulty',
        'cooking_time'
    ],
    recipe_versions: [
        'id',
        'recipe_id',
        'version_number',
        'title',
        'description',
        'ingredients',
        'instructions',
        'chefs_note',
        'changed_ingredients',
        'created_at',
        'step0_summary',
        'step0_audio_url',
        'difficulty',
        'cooking_time'
    ]
};

export async function checkSchema(): Promise<void> {
    // Emergency bypass: allows server to start even if schema validation fails
    // Use only in emergency situations (e.g., false positive blocking deployment)
    if (process.env.SKIP_SCHEMA_CHECK === 'true') {
        logger.warn('[SchemaGuard] ⚠️  SCHEMA VALIDATION SKIPPED (SKIP_SCHEMA_CHECK=true)');
        logger.warn('[SchemaGuard] ⚠️  This is an emergency bypass. Remove SKIP_SCHEMA_CHECK ASAP.');
        return;
    }

    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    logger.info('[SchemaGuard] 🛡️  Validating database schema...');

    for (const [tableName, requiredColumns] of Object.entries(REQUIRED_SCHEMA)) {
        try {
            // Probe-based validation: Select with explicit column names
            // If any column doesn't exist, Supabase will return an error
            // This is more reliable than querying information_schema (which isn't accessible via PostgREST)
            const selectColumns = requiredColumns.join(',');

            const { data, error } = await supabase
                .from(tableName)
                .select(selectColumns)
                .limit(1);

            if (error) {
                // Parse the error to identify missing columns
                const errorMessage = error.message || '';

                // Supabase returns specific errors for missing columns
                if (errorMessage.includes('column') || errorMessage.includes('does not exist')) {
                    logger.error(`[SchemaGuard] ❌ Schema validation failed for table '${tableName}':`, error.message);
                    throw new Error(
                        `Schema validation failed: Table '${tableName}' has schema issues: ${error.message}\n` +
                        `This usually means migrations were not run. Please run the latest migrations before starting the server.`
                    );
                }

                // For other errors (e.g., table doesn't exist), also fail
                logger.error(`[SchemaGuard] ❌ Failed to validate table '${tableName}':`, error);
                throw new Error(`Schema validation failed: Could not query table '${tableName}': ${error.message}`);
            }

            // If we get here, all columns exist (query succeeded)
            logger.info(`[SchemaGuard] ✅ Table '${tableName}' schema valid (${requiredColumns.length} columns)`);
        } catch (err) {
            // Re-throw to crash the server
            throw err;
        }
    }

    logger.info('[SchemaGuard] ✅ All database schemas validated successfully');
}
