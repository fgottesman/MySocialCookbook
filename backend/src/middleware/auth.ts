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
