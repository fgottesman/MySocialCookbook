import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
    // Warn but don't crash immediately to allow for development setup
    console.warn('Missing Supabase environment variables (SUPABASE_URL or SUPABASE_ANON_KEY).');
}

export const supabase = createClient(
    supabaseUrl || '',
    supabaseKey || ''
);
