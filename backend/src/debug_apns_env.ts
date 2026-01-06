
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';

const envPath = path.resolve(process.cwd(), '.env');
console.log(`Loading .env from: ${envPath}`);

if (fs.existsSync(envPath)) {
    dotenv.config({ path: envPath });
} else {
    console.error('❌ .env file not found!');
}

const APNS_KEY = process.env.APNS_KEY;
const APNS_KEY_ID = process.env.APNS_KEY_ID;
const APPLE_TEAM_ID = process.env.APPLE_TEAM_ID;

console.log('--- Checking APNs Config ---');

if (!APNS_KEY) {
    console.error('❌ APNS_KEY is missing');
} else {
    // Check key format
    const hasHeader = APNS_KEY.includes('BEGIN PRIVATE KEY');
    const hasFooter = APNS_KEY.includes('END PRIVATE KEY');

    // Simulate the replacement done in apns.ts
    const keyContent = APNS_KEY.replace(/\\n/g, '\n');
    const lineCount = keyContent.split('\n').length;

    console.log(`APNS_KEY Length: ${APNS_KEY.length}`);
    console.log(`APNS_KEY Header check: ${hasHeader ? '✅' : '❌'}`);
    console.log(`APNS_KEY Footer check: ${hasFooter ? '✅' : '❌'}`);
    console.log(`APNS_KEY Line count (after \\n replacement): ${lineCount}`);

    if (lineCount < 4) {
        console.warn("⚠️ APNS_KEY might be a single line. Ensure \\n literals are used correctly or the key is multiline.");
    }
}

if (!APNS_KEY_ID) {
    console.error('❌ APNS_KEY_ID is missing');
} else {
    console.log(`APNS_KEY_ID: ${APNS_KEY_ID}`);
}

if (!APPLE_TEAM_ID) {
    console.error('❌ APPLE_TEAM_ID is missing');
} else {
    console.log(`APPLE_TEAM_ID: ${APPLE_TEAM_ID}`);
}
