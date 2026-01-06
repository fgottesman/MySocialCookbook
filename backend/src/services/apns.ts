
import jwt from 'jsonwebtoken';
import https from 'https';

const APNS_KEY = process.env.APNS_KEY;
const APNS_KEY_ID = process.env.APNS_KEY_ID;
const APPLE_TEAM_ID = process.env.APPLE_TEAM_ID;

interface PushPayload {
    title: string;
    body: string;
    recipeId?: string;
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

        const token = jwt.sign(
            { iss: APPLE_TEAM_ID, iat: now },
            APNS_KEY.replace(/\\n/g, '\n'), // Handle escaped newlines from env
            {
                algorithm: 'ES256',
                header: { alg: 'ES256', kid: APNS_KEY_ID }
            }
        );

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

                // Use sandbox for development, production for App Store
                const host = process.env.NODE_ENV === 'production'
                    ? 'api.push.apple.com'
                    : 'api.sandbox.push.apple.com';

                const options = {
                    hostname: host,
                    port: 443,
                    path: `/3/device/${deviceToken}`,
                    method: 'POST',
                    headers: {
                        'authorization': `bearer ${token}`,
                        'apns-topic': 'com.mysocialcookbook',
                        'apns-push-type': 'alert',
                        'content-type': 'application/json',
                        'content-length': Buffer.byteLength(body)
                    }
                };

                const req = https.request(options, (res) => {
                    console.log(`APNs response status: ${res.statusCode}`);
                    resolve(res.statusCode === 200);
                });

                req.on('error', (e) => {
                    console.error('APNs request error:', e);
                    resolve(false);
                });

                req.write(body);
                req.end();
            } catch (error) {
                console.error('APNs send error:', error);
                resolve(false);
            }
        });
    }
}

export const apnsService = new APNsService();
