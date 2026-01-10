import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import logger from '../utils/logger';

export class UserController {
    static async registerDevice(req: AuthRequest, res: Response) {
        let userId: string | undefined;
        try {
            const { deviceToken, platform } = req.body;
            userId = req.user.id;

            if (!deviceToken || !platform) {
                return res.status(400).json({ error: 'deviceToken and platform are required' });
            }

            const { data, error } = await req.supabase
                .from('user_devices')
                .upsert({
                    user_id: userId,
                    device_token: deviceToken,
                    platform: platform,
                    updated_at: new Date().toISOString()
                }, { onConflict: 'user_id, device_token' })
                .select()
                .single();

            if (error) throw error;
            res.json({ success: true, device: data });
        } catch (error: any) {
            logger.error(`Device registration error: ${error.message}`, { userId });
            res.status(500).json({ error: error.message });
        }
    }

    static async getPreferences(req: AuthRequest, res: Response) {
        let userIdParam: string | undefined;
        try {
            const { userId } = req.params;
            userIdParam = userId;
            const authedUserId = req.user.id;

            if (userId !== authedUserId) {
                return res.status(403).json({ error: 'Forbidden: You can only access your own preferences' });
            }

            const { data, error } = await req.supabase
                .from('user_preferences')
                .select('*')
                .eq('user_id', userId)
                .single();

            if (error && error.code !== 'PGRST116') throw error;
            res.json(data || { user_id: userId });
        } catch (error: any) {
            logger.error(`Error fetching preferences: ${error.message}`, { userId: userIdParam });
            res.status(500).json({ error: error.message });
        }
    }

    static async updatePreferences(req: AuthRequest, res: Response) {
        let userIdParam: string | undefined;
        try {
            const { userId } = req.params;
            userIdParam = userId;
            const authedUserId = req.user.id;
            const updates = req.body;

            if (userId !== authedUserId) {
                return res.status(403).json({ error: 'Forbidden: You can only update your own preferences' });
            }

            const { data, error } = await req.supabase
                .from('user_preferences')
                .upsert({
                    user_id: userId,
                    ...updates,
                    updated_at: new Date().toISOString()
                }, { onConflict: 'user_id' })
                .select()
                .single();

            if (error) throw error;
            res.json({ success: true, preferences: data });
        } catch (error: any) {
            logger.error(`Error updating preferences: ${error.message}`, { userId: userIdParam });
            res.status(500).json({ error: error.message });
        }
    }
}
