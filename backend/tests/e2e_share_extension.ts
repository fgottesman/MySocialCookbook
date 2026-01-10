import axios from 'axios';
import dotenv from 'dotenv';

dotenv.config();

/**
 * E2E Test: Share Extension Flow
 * 
 * This test validates the critical Share Extension flow:
 * 1. Legacy Auth (No Bearer token, userId in body) - For builds 0-5
 * 2. Modern Auth (Bearer token) - For build 6+
 * 3. Schema compatibility
 * 
 * Run with: npm run test:e2e
 */

const BASE_URL = process.env.TEST_API_URL || 'http://localhost:8080/api';
const TEST_USER_ID = process.env.TEST_USER_ID || '00000000-0000-0000-0000-000000000000';
const TEST_AUTH_TOKEN = process.env.TEST_AUTH_TOKEN;

interface TestResult {
    name: string;
    passed: boolean;
    error?: string;
}

const results: TestResult[] = [];

async function testLegacyAuth() {
    console.log('\n🧪 Test 1: Legacy Auth (No Bearer Token)');

    try {
        // Simulate Share Extension request without Authorization header
        const response = await axios.post(
            `${BASE_URL}/process-recipe`,
            {
                url: 'https://www.instagram.com/reel/test/',
                userId: TEST_USER_ID
            },
            {
                headers: {
                    'Content-Type': 'application/json'
                },
                validateStatus: () => true // Don't throw on any status
            }
        );

        if (response.status === 200 && response.data.success) {
            console.log('✅ Legacy auth accepted');
            results.push({ name: 'Legacy Auth', passed: true });
        } else {
            throw new Error(`Unexpected response: ${response.status} - ${JSON.stringify(response.data)}`);
        }
    } catch (error: any) {
        console.error('❌ Legacy auth failed:', error.message);
        results.push({ name: 'Legacy Auth', passed: false, error: error.message });
    }
}

async function testModernAuth() {
    console.log('\n🧪 Test 2: Modern Auth (Bearer Token)');

    if (!TEST_AUTH_TOKEN) {
        console.log('⏭️  Skipping (TEST_AUTH_TOKEN not set)');
        results.push({ name: 'Modern Auth', passed: true, error: 'Skipped: No test token' });
        return;
    }

    try {
        const response = await axios.post(
            `${BASE_URL}/process-recipe`,
            {
                url: 'https://www.tiktok.com/@test/video/12345'
            },
            {
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${TEST_AUTH_TOKEN}`
                },
                validateStatus: () => true
            }
        );

        if (response.status === 200 && response.data.success) {
            console.log('✅ Modern auth accepted');
            results.push({ name: 'Modern Auth', passed: true });
        } else {
            throw new Error(`Unexpected response: ${response.status} - ${JSON.stringify(response.data)}`);
        }
    } catch (error: any) {
        console.error('❌ Modern auth failed:', error.message);
        results.push({ name: 'Modern Auth', passed: false, error: error.message });
    }
}

async function testHealthCheck() {
    console.log('\n🧪 Test 3: Health Check Endpoint');

    try {
        const response = await axios.get(`${BASE_URL}/health/share-extension`, {
            validateStatus: () => true
        });

        if (response.status === 200 && response.data.services) {
            const { database, gemini, storage, rapidapi } = response.data.services;

            console.log(`  Database: ${database.healthy ? '✅' : '❌'}`);
            console.log(`  Gemini: ${gemini.healthy ? '✅' : '❌'}`);
            console.log(`  Storage: ${storage.healthy ? '✅' : '❌'}`);
            console.log(`  RapidAPI: ${rapidapi.healthy ? '✅' : '❌'}`);

            if (database.healthy) {
                console.log('✅ Health check passed');
                results.push({ name: 'Health Check', passed: true });
            } else {
                throw new Error('Database unhealthy');
            }
        } else {
            throw new Error(`Unexpected response: ${response.status}`);
        }
    } catch (error: any) {
        console.error('❌ Health check failed:', error.message);
        results.push({ name: 'Health Check', passed: false, error: error.message });
    }
}

async function runTests() {
    console.log('🚀 Starting E2E Tests for Share Extension\n');
    console.log(`Target: ${BASE_URL}`);
    console.log(`Test User ID: ${TEST_USER_ID}`);

    await testHealthCheck();
    await testLegacyAuth();
    await testModernAuth();

    // Print summary
    console.log('\n' + '='.repeat(50));
    console.log('📊 Test Summary\n');

    const passed = results.filter(r => r.passed).length;
    const failed = results.filter(r => !r.passed).length;

    results.forEach(result => {
        const icon = result.passed ? '✅' : '❌';
        console.log(`${icon} ${result.name}${result.error ? ` (${result.error})` : ''}`);
    });

    console.log(`\nTotal: ${results.length} | Passed: ${passed} | Failed: ${failed}`);
    console.log('='.repeat(50));

    // Exit with error code if any tests failed
    if (failed > 0) {
        process.exit(1);
    }
}

// Run tests
runTests().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});
