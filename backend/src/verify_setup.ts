
import { supabase } from './db/supabase';

async function verifyConnection() {
    console.log("Verifying Supabase Connection...");

    // 1. Check Auth service (should work even with anon key)
    const { data: authData, error: authError } = await supabase.auth.getSession();
    if (authError) {
        console.error("❌ Auth Error:", authError.message);
    } else {
        console.log("✅ Auth Service Reachable");
    }

    // 2. Check Database Table (profiles)
    // This expects the user to have run the SQL schema.
    const { data, error, count } = await supabase
        .from('profiles')
        .select('*', { count: 'exact', head: true });

    if (error) {
        if (error.code === '42P01') { // undefined_table
            console.error("❌ Table 'profiles' does not exist. Please run the migration SQL.");
        } else {
            console.error("❌ Database Error:", error.message, error.code);
        }
    } else {
        console.log("✅ Database Table 'profiles' found.");
    }
}

verifyConnection();
