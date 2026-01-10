
import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import axios from 'axios';
import chalk from 'chalk';
import { AI_MODELS } from './config/ai_models';

dotenv.config();

async function runDoctor() {
    console.log(chalk.bold.blue('\n👨‍⚕️ ClipCook Backend Doctor - System Diagnostic\n'));

    let errors = 0;
    let warnings = 0;

    // 1. Environment Variables
    console.log(chalk.yellow('Step 1: Checking Environment Variables...'));
    const requiredEnv = [
        'GEMINI_API_KEY',
        'SUPABASE_URL',
        'SUPABASE_ANON_KEY',
        'RAPIDAPI_KEY',
        'APPLE_TEAM_ID',
        'APNS_KEY_ID',
        'APNS_KEY'
    ];

    requiredEnv.forEach(env => {
        if (!process.env[env]) {
            console.log(chalk.red(`  ❌ Missing: ${env}`));
            errors++;
        } else {
            console.log(chalk.green(`  ✅ Found: ${env}`));
        }
    });

    // 2. Supabase Connection & Schema
    console.log(chalk.yellow('\nStep 2: Testing Supabase Connectivity & Schema...'));
    try {
        const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_ANON_KEY!);

        // Check profiles table (foundational)
        const { error: profileError } = await supabase.from('profiles').select('*', { count: 'exact', head: true }).limit(1);
        if (profileError) {
            if (profileError.code === '42P01') console.log(chalk.red('  ❌ Table "profiles" missing - run migrations!'));
            else throw profileError;
        } else {
            console.log(chalk.green('  ✅ Table "profiles" found'));
        }

        // Check recipes table & latest data
        const { data: recipeData, error: recipeError } = await supabase.from('recipes').select('id, title').order('created_at', { ascending: false }).limit(1);
        if (recipeError) throw recipeError;

        if (recipeData && recipeData.length > 0) {
            console.log(chalk.green(`  ✅ Table "recipes" found (Latest: "${recipeData[0].title}")`));
        } else {
            console.log(chalk.cyan('  ℹ️ Table "recipes" found but is empty'));
        }
    } catch (e: any) {
        console.log(chalk.red(`  ❌ Supabase Diagnostic Failed: ${e.message}`));
        errors++;
    }

    // 3. APNs Configuration
    console.log(chalk.yellow('\nStep 3: Validating APNs Configuration...'));
    const apnsKey = process.env.APNS_KEY || '';
    if (apnsKey.includes('BEGIN PRIVATE KEY') && apnsKey.includes('END PRIVATE KEY')) {
        console.log(chalk.green('  ✅ APNS_KEY format looks valid'));
    } else if (apnsKey) {
        console.log(chalk.red('  ❌ APNS_KEY missing standard PEM headers'));
        errors++;
    }

    // 4. Gemini API Health
    console.log(chalk.yellow('\nStep 4: Testing Gemini API Connectivity...'));
    try {
        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models?key=${process.env.GEMINI_API_KEY}`;
        const response = await axios.get(geminiUrl);
        if (response.status === 200) {
            console.log(chalk.green('  ✅ Gemini API Reachable'));
            const hasModel = response.data.models.some((m: any) => m.name.includes(AI_MODELS.RECIPE_ENGINE));
            if (hasModel) {
                console.log(chalk.green(`  ✅ Model ${AI_MODELS.RECIPE_ENGINE} is available`));
            } else {
                console.log(chalk.red(`  ❌ Model ${AI_MODELS.RECIPE_ENGINE} NOT found in your API key's scope`));
                errors++;
            }
        }
    } catch (e: any) {
        console.log(chalk.red(`  ❌ Gemini API Test Failed: ${e.message}`));
        errors++;
    }

    // 5. Build Readiness
    console.log(chalk.yellow('\nStep 5: Checking Build Readiness...'));
    try {
        // Just check if dist exists as a proxy for 'has built'
        const fs = await import('fs');
        if (fs.existsSync('./dist')) {
            console.log(chalk.green('  ✅ Build folder (dist) exists'));
        } else {
            console.log(chalk.cyan('  ℹ️ Build folder (dist) missing. Run npm run build.'));
            warnings++;
        }
    } catch (e) { }

    // Summary
    console.log(chalk.bold('\n--- Diagnostic Summary ---'));
    if (errors === 0) {
        console.log(chalk.bold.green(`\n✨ ALL SYSTEMS GO! (${warnings} warnings)`));
    } else {
        console.log(chalk.bold.red(`\n🚨 SYSTEM UNHEALTHY: ${errors} errors found.`));
    }
    console.log('\n');

    process.exit(errors > 0 ? 1 : 0);
}

runDoctor();
