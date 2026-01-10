import { SupabaseClient, User } from '@supabase/supabase-js';

declare global {
    namespace Express {
        interface Request {
            user: User;
            supabase: SupabaseClient;
        }
    }
}
