
import { spawn, ChildProcess } from 'child_process';
import axios from 'axios';
import path from 'path';

const PORT = 8081;
const API_URL = `http://localhost:${PORT}/api/process-recipe`;
const HEALTH_URL = `http://localhost:${PORT}/health`;

async function wait(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function waitForServer(): Promise<boolean> {
    const maxRetries = 30; // 30 seconds
    for (let i = 0; i < maxRetries; i++) {
        try {
            await axios.get(HEALTH_URL);
            return true;
        } catch (e) {
            await wait(1000);
        }
    }
    return false;
}

async function runTest() {
    let server: ChildProcess | null = null;
    let exitCode = 0;

    try {
        console.log('🚀 Starting Backend Server for Testing...');

        // Spawn the server process
        server = spawn('npx', ['ts-node', 'src/index.ts'], {
            cwd: path.join(__dirname, '..'),
            env: { ...process.env, PORT: PORT.toString() },
            stdio: 'inherit' // Pipe output so we can see server logs
        });

        // Wait for server to be ready
        const ready = await waitForServer();
        if (!ready) {
            console.error('❌ Server failed to start in time.');
            process.exit(1);
        }
        console.log('✅ Server is up!');

        // --- TEST CASE: Legacy Share Extension (No Token, userId in Body) ---
        console.log('\n🧪 Testing Legacy Share Extension Request...');

        const payload = {
            userId: 'test-user-uuid-12345',
            url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' // Rick Roll as test URL
        };

        try {
            // Note: No Authorization header!
            const response = await axios.post(API_URL, payload);

            console.log('Response Status:', response.status);
            console.log('Response Body:', response.data);

            if (response.status === 200 && response.data.success === true) {
                console.log('✅ TEST PASSED: Legacy request accepted.');
            } else {
                console.error('❌ TEST FAILED: Unexpected response.', response.data);
                exitCode = 1;
            }

        } catch (error: any) {
            if (error.response) {
                console.error(`❌ TEST FAILED: Server returned ${error.response.status}`, error.response.data);
            } else {
                console.error('❌ TEST FAILED: Request error', error.message);
            }
            exitCode = 1;
        }

    } catch (e: any) {
        console.error('❌ Unexpected Test Script Error:', e);
        exitCode = 1;
    } finally {
        if (server) {
            console.log('\n🛑 Stopping Server...');
            server.kill();
        }
        process.exit(exitCode);
    }
}

runTest();
