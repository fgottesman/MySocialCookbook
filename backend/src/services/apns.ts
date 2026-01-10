
import http2 from 'http2';
import crypto from 'crypto';
import { supabase } from '../db/supabase';
import logger from '../utils/logger';

const APNS_KEY = process.env.APNS_KEY;
const APNS_KEY_ID = process.env.APNS_KEY_ID;
const APPLE_TEAM_ID = process.env.APPLE_TEAM_ID;

// Helper for base64url encoding
function base64url(buf: Buffer): string {
    return buf.toString('base64')
        .replace(/=/g, '')
        .replace(/\+/g, '-')
        .replace(/\//g, '_');
}

interface PushPayload {
    title: string;
    body: string;
    recipeId?: string;
}

// Debug configuration on startup
if (process.env.NODE_ENV !== 'test') {
    logger.info('APNs Configuration Check', {
        env: process.env.NODE_ENV,
        teamIdPresent: !!APPLE_TEAM_ID,
        keyIdPresent: !!APNS_KEY_ID,
        keyPresent: !!APNS_KEY
    });
}

export class APNsService {
    private cachedToken: string | null = null;
    private tokenExpiry: number = 0;

    private generateToken(): string {
        const now = Math.floor(Date.now() / 1000);

        // Token valid for 1 hour, refresh 5 mins before expiry
        if (this.cachedToken && this.tokenExpiry > now + 300) {
            return this.cachedToken;
        }

        if (!APNS_KEY || !APNS_KEY_ID || !APPLE_TEAM_ID) {
            throw new Error('APNs credentials not configured');
        }

        const teamId = APPLE_TEAM_ID.trim();
        const keyId = APNS_KEY_ID.trim();
        const key = APNS_KEY.trim().replace(/\\n/g, '\n');

        // 1. Manually construct Header
        const header = {
            alg: 'ES256',
            kid: keyId
        };

        // 2. Manually construct Payload
        const payload = {
            iss: teamId,
            iat: now
        };

        // Base64url encode them
        const headerPart = base64url(Buffer.from(JSON.stringify(header)));
        const payloadPart = base64url(Buffer.from(JSON.stringify(payload)));

        // 3. Sign the content
        const signContent = `${headerPart}.${payloadPart}`;

        // Correct way to sign ES256 in Node.js crypto:
        const signature = crypto.sign(
            'sha256',
            Buffer.from(signContent),
            {
                key: key,
                format: 'pem',
                type: 'pkcs8',
                dsaEncoding: 'ieee-p1363' // Ensures raw R|S output for ES256 compliance
            }
        );

        const signaturePart = base64url(signature);
        const token = `${signContent}.${signaturePart}`;

        logger.debug('APNs Token Generated successfully');

        this.cachedToken = token;
        this.tokenExpiry = now + 3600; // 1 hour
        return token;
    }

    async sendNotification(deviceToken: string, payload: PushPayload): Promise<boolean> {
        return new Promise((resolve) => {
            try {
                const token = this.generateToken();

                const apnsPayload = {
                    aps: {
                        alert: {
                            title: payload.title,
                            body: payload.body
                        },
                        sound: 'default',
                        badge: 1
                    },
                    recipeId: payload.recipeId
                };

                const body = JSON.stringify(apnsPayload);

                // Determine APNs environment
                const isProduction = process.env.APNS_ENV
                    ? process.env.APNS_ENV === 'production'
                    : process.env.NODE_ENV === 'production';

                const host = isProduction
                    ? 'https://api.push.apple.com'
                    : 'https://api.sandbox.push.apple.com';

                logger.debug(`Connecting to APNs: ${host}`);

                const client = http2.connect(host);

                client.on('error', (err) => {
                    logger.error('APNs client connection error', { error: err });
                    resolve(false);
                });

                const req = client.request({
                    ':method': 'POST',
                    ':path': `/3/device/${deviceToken}`,
                    'authorization': `bearer ${token}`,
                    'apns-topic': 'Freddy.ClipCook',
                    'apns-push-type': 'alert',
                    'content-type': 'application/json',
                    'content-length': Buffer.byteLength(body)
                });

                req.on('response', (headers, flags) => {
                    const status = headers[':status'];

                    if (status === 200) {
                        logger.info(`APNs notification delivered successfully to ${deviceToken.substring(0, 8)}...`);
                        resolve(true);
                    } else {
                        let data = '';
                        req.on('data', (chunk) => { data += chunk; });
                        req.on('end', async () => {
                            logger.error(`APNs delivery failed with status ${status}`, { data });

                            // 410 = Unregistered (Token no longer valid)
                            // 400 = BadDeviceToken (Token invalid)
                            if (status === 410 || status === 400) {
                                logger.info(`Removing invalid device token: ${deviceToken.substring(0, 8)}...`);
                                try {
                                    await supabase
                                        .from('user_devices')
                                        .delete()
                                        .eq('device_token', deviceToken);
                                } catch (dbError) {
                                    logger.error('Failed to remove invalid token from DB', { error: dbError });
                                }
                            }

                            resolve(false);
                        });
                    }

                    client.close();
                });

                req.on('error', (err) => {
                    logger.error('APNs request stream error', { error: err });
                    client.close();
                    resolve(false);
                });

                req.write(body);
                req.end();

            } catch (error) {
                logger.error('APNs Service unexpected error', { error });
                resolve(false);
            }
        });
    }
}

export const apnsService = new APNsService();
