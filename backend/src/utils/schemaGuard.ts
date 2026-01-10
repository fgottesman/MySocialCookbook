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
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    logger.info('[SchemaGuard] 🛡️  Validating database schema...');

    for (const [tableName, requiredColumns] of Object.entries(REQUIRED_SCHEMA)) {
        try {
            // Query information_schema to get all columns for this table
            const { data, error } = await supabase
                .from('information_schema.columns' as any)
                .select('column_name')
                .eq('table_schema', 'public')
                .eq('table_name', tableName);

            if (error) {
                logger.error(`[SchemaGuard] ❌ Failed to query schema for table '${tableName}':`, error);
                throw new Error(`Schema validation failed: Could not query table '${tableName}'`);
            }

            if (!data || data.length === 0) {
                logger.error(`[SchemaGuard] ❌ Table '${tableName}' does not exist or has no columns`);
                throw new Error(`Schema validation failed: Table '${tableName}' not found`);
            }

            // Extract column names from the result
            const existingColumns = new Set(data.map((row: any) => row.column_name));

            // Check for missing required columns
            const missingColumns = requiredColumns.filter(col => !existingColumns.has(col));

            if (missingColumns.length > 0) {
                logger.error(
                    `[SchemaGuard] ❌ Table '${tableName}' is missing required columns:`,
                    missingColumns
                );
                throw new Error(
                    `Schema validation failed: Table '${tableName}' is missing columns: ${missingColumns.join(', ')}\n` +
                    `This usually means migrations were not run. Please run the latest migrations before starting the server.`
                );
            }

            logger.info(`[SchemaGuard] ✅ Table '${tableName}' schema valid (${requiredColumns.length} columns)`);
        } catch (err) {
            // Re-throw to crash the server
            throw err;
        }
    }

    logger.info('[SchemaGuard] ✅ All database schemas validated successfully');
}
