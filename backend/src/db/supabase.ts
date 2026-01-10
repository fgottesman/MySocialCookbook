import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

export const supabaseUrl = process.env.SUPABASE_URL || '';
export const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || '';
export const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

if (!supabaseUrl || !supabaseAnonKey) {
    console.warn('Missing Supabase environment variables.');
}

// Global client still uses Service Role for administrative tasks if needed, 
// but we'll prefer per-request clients in middleware for RLS.
export const supabase = createClient(
    supabaseUrl,
    supabaseServiceRoleKey || supabaseAnonKey
);
