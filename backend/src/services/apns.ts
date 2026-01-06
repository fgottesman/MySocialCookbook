
import http2 from 'http2';
import crypto from 'crypto';

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
    console.log('--- APNs Configuration Check ---');
    console.log(`NODE_ENV: ${process.env.NODE_ENV}`);
    console.log(`Server Time: ${new Date().toISOString()}`);
    console.log(`APPLE_TEAM_ID: ${APPLE_TEAM_ID ? APPLE_TEAM_ID.substring(0, 3) + '...' : 'MISSING'}`);
    console.log(`APNS_KEY_ID: ${APNS_KEY_ID ? APNS_KEY_ID.substring(0, 3) + '...' : 'MISSING'}`);
    console.log(`APNS_KEY Present: ${!!APNS_KEY}`);
    if (APNS_KEY) {
        const keyContent = APNS_KEY.trim().replace(/\\n/g, '\n');
        console.log(`APNS_KEY Length: ${keyContent.length}`);
        console.log(`APNS_KEY Prefix: ${keyContent.substring(0, 15)}...`);
        console.log(`APNS_KEY Suffix: ...${keyContent.substring(keyContent.length - 15)}`);

        // Count newlines to verify format
        const newlineCount = (keyContent.match(/\n/g) || []).length;
        console.log(`APNS_KEY Newlines: ${newlineCount}`);
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

        const teamId = APPLE_TEAM_ID.trim();
        const keyId = APNS_KEY_ID.trim();
        const key = APNS_KEY.trim().replace(/\\n/g, '\n');

        // 1. Manually construct Header (Minimal for APNs)
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
        const signer = crypto.createSign('RSA-SHA256'); // Wait, APNs needs ES256 (ECDSA with SHA-256)

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

        console.log('--- APNs Manual Token Generated ---');
        console.log(`Header (No typ): ${JSON.stringify(header)}`);
        console.log(`Payload: ${JSON.stringify(payload)}`);
        console.log(`Server Time Now: ${now}`);
        console.log('---------------------------');

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
                    'apns-topic': 'Freddy.MySocialCookbook',
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
