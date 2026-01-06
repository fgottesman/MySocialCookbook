
import jwt from 'jsonwebtoken';
import http2 from 'http2';

const APNS_KEY = process.env.APNS_KEY;
const APNS_KEY_ID = process.env.APNS_KEY_ID;
const APPLE_TEAM_ID = process.env.APPLE_TEAM_ID;


interface PushPayload {
    title: string;
    body: string;
    recipeId?: string;
}

// Debug configuration on startup
if (process.env.NODE_ENV !== 'test') {
    console.log('--- APNs Configuration Check ---');
    console.log(`NODE_ENV: ${process.env.NODE_ENV}`);
    console.log(`APPLE_TEAM_ID: ${APPLE_TEAM_ID ? APPLE_TEAM_ID.substring(0, 3) + '...' : 'MISSING'}`);
    console.log(`APNS_KEY_ID: ${APNS_KEY_ID ? APNS_KEY_ID.substring(0, 3) + '...' : 'MISSING'}`);
    console.log(`APNS_KEY Present: ${!!APNS_KEY}`);
    if (APNS_KEY) {
        const keyContent = APNS_KEY.replace(/\\n/g, '\n');
        console.log(`APNS_KEY Length: ${keyContent.length}`);
        console.log(`APNS_KEY Starts With: ${keyContent.substring(0, 20).replace(/\n/g, ' ')}...`);
    }
    console.log('--------------------------------');
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

                // Determine APNs environment:
                // 1. Check strict APNS_ENV override (sandbox/production)
                // 2. Fallback to NODE_ENV (production -> production, else -> sandbox)
                const isProduction = process.env.APNS_ENV
                    ? process.env.APNS_ENV === 'production'
                    : process.env.NODE_ENV === 'production';

                const host = isProduction
                    ? 'https://api.push.apple.com'
                    : 'https://api.sandbox.push.apple.com';

                console.log(`Using APNs Server: ${host} (Env: ${process.env.APNS_ENV || 'auto'}, Mode: ${isProduction ? 'Production' : 'Sandbox'})`);

                const client = http2.connect(host);

                client.on('error', (err) => {
                    console.error('APNs client error:', err);
                    resolve(false);
                });

                const req = client.request({
                    ':method': 'POST',
                    ':path': `/3/device/${deviceToken}`,
                    'authorization': `bearer ${token}`,
                    'apns-topic': 'com.mysocialcookbook',
                    'apns-push-type': 'alert',
                    'content-type': 'application/json',
                    'content-length': Buffer.byteLength(body)
                });

                req.on('response', (headers, flags) => {
                    const status = headers[':status'];
                    console.log(`APNs response status: ${status}`);

                    if (status === 200) {
                        resolve(true);
                    } else {
                        // Consume response data to log error details if needed
                        let data = '';
                        req.on('data', (chunk) => { data += chunk; });
                        req.on('end', () => {
                            console.error(`APNs error response: ${data}`);
                            resolve(false);
                        });
                    }

                    client.close();
                });

                req.on('error', (err) => {
                    console.error('APNs request error:', err);
                    client.close();
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
