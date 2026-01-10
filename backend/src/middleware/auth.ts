import { Request, Response, NextFunction } from 'express';
import { createClient, SupabaseClient, User } from '@supabase/supabase-js';
import { supabaseUrl, supabaseAnonKey } from '../db/supabase';

export interface AuthRequest extends Request {
    user: User;
    supabase: SupabaseClient;
}

export const authenticate = async (req: Request, res: Response, next: NextFunction) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
        }

        const token = authHeader.split(' ')[1];

        // Create a temporary client with the user's token to verify and for subsequent RLS-respecting calls
        const userClient = createClient(supabaseUrl, supabaseAnonKey, {
            global: {
                headers: {
                    Authorization: `Bearer ${token}`
                }
            }
        });

        const { data, error } = await userClient.auth.getUser();

        if (error || !data.user) {
            console.error('[AuthMiddleware] ❌ JWT Verification Failed:', error?.message);
            return res.status(401).json({ error: 'Unauthorized: Invalid token' });
        }

        // Attach user and RLS-compliant client to request
        (req as AuthRequest).user = data.user;
        (req as AuthRequest).supabase = userClient;

        next();
    } catch (err) {
        console.error('[AuthMiddleware] ❌ Unexpected Error:', err);
        res.status(500).json({ error: 'Internal Server Error during authentication' });
    }
};

/**
 * HOTFIX (Build 6 Compatibility):
 * Allows requests with NO token to proceed using the Admin (Service Role) client.
 * This bypasses RLS to allow the iOS client (which forgot headers) to save versions.
 * 
 * TODO: Remove this in Build 7 once all clients are sending tokens.
 */
import { supabaseServiceRoleKey } from '../db/supabase';

export const allowAnonymousWithAdminClient = async (req: Request, res: Response, next: NextFunction) => {
    try {
        const authHeader = req.headers.authorization;

        // 1. If token is present, try standard authentication first
        if (authHeader && authHeader.startsWith('Bearer ')) {
            return authenticate(req, res, next);
        }

        // 2. If no token, use Admin Client (Service Role)
        // console.warn('[AuthMiddleware] ⚠️ No Auth Token - Using Admin Bypass for Route:', req.originalUrl);

        const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
            auth: {
                autoRefreshToken: false,
                persistSession: false
            }
        });

        // Attach admin client to request
        // Mock a user object since controller doesn't seem to use req.user for this specific route logic
        // But we provide a dummy ID just in case to prevent null pointer exceptions if logging accesses it
        (req as AuthRequest).user = { id: '00000000-0000-0000-0000-000000000000', aud: 'hotfix_bypass', created_at: new Date().toISOString() } as User;
        (req as AuthRequest).supabase = adminClient;

        next();
    } catch (err) {
        console.error('[AuthMiddleware] ❌ Error in Anonymous Bypass:', err);
        res.status(500).json({ error: 'Internal Server Error during auth bypass' });
    }
};
