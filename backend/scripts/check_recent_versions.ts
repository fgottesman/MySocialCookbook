
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';

// Load environment variables
dotenv.config({ path: path.join(__dirname, '../.env') });

const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || '';

if (!supabaseUrl || !supabaseKey) {
    console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_KEY/SUPABASE_SERVICE_ROLE_KEY');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkRecent() {
    console.log('--- Checking Recent Recipe Versions ---');

    const { data: versions, error } = await supabase
        .from('recipe_versions')
        .select(`
            id,
            recipe_id,
            version_number,
            title,
            created_at
        `)
        .order('created_at', { ascending: false })
        .limit(10);

    if (error) {
        console.error('Error fetching versions:', error);
        return;
    }

    if (!versions || versions.length === 0) {
        console.log('No versions found in the database.');
    } else {
        console.log(`Found ${versions.length} recent versions:`);
        versions.forEach(v => {
            console.log(`[${v.created_at}] Recipe: ${v.recipe_id} | v${v.version_number} | Title: "${v.title}"`);
        });
    }

    console.log('\n--- Checking Recent Recipes (Modified) ---');
    const { data: recipes, error: rError } = await supabase
        .from('recipes')
        .select('id, title, updated_at, created_at')
        .order('updated_at', { ascending: false })
        .limit(10);

    if (rError) {
        console.error('Error fetching recipes:', rError);
        return;
    }

    if (recipes && recipes.length > 0) {
        recipes.forEach(r => {
            console.log(`[Updated: ${r.updated_at}] ID: ${r.id} | Title: "${r.title}"`);
        });
    }
}

checkRecent();
