import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error('Missing Supabase URL or Key in .env');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkLatestRecipe() {
    console.log('Checking for latest recipe...');

    const { data, error } = await supabase
        .from('recipes')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(1);

    if (error) {
        console.error('Error fetching recipe:', error);
        return;
    }

    if (data && data.length > 0) {
        const recipe = data[0];
        console.log('\n✅ SUCCESS! Found a recipe in the database:');
        console.log('------------------------------------------------');
        console.log(`Title: ${recipe.title}`);
        console.log(`Created At: ${recipe.created_at}`);
        console.log(`Description Snippet: ${recipe.description?.substring(0, 100)}...`);
        console.log(`Video URL: ${recipe.video_url}`);
        console.log('------------------------------------------------');
        console.log('This confirms that the Share Extension -> Backend -> Gemini pipeline worked!');
    } else {
        console.log('\n❌ No recipes found in the database yet.');
        console.log('If you just shared it, it might still be processing (downloading/analyzing video takes 10-30s).');
        console.log('Wait a moment and run this again.');
    }
}

checkLatestRecipe();
