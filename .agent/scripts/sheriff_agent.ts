import { GoogleGenerativeAI } from "@google/generative-ai";
import { execSync } from "child_process";
import * as dotenv from "dotenv";
import * as path from "path";
import * as fs from "fs";

/**
 * 🤠 THE SHERIFF AGENT (Production Auditor Edition)
 * Runs every 15 minutes to audit recent pushes against the Review & Push Protocol
 * and monitor the health of the live production servers and services.
 */

// Load environment variables from backend/.env
const backendEnvPath = path.resolve(process.cwd(), "backend", ".env");
if (fs.existsSync(backendEnvPath)) {
    dotenv.config({ path: backendEnvPath });
}

const API_KEY = process.env.GEMINI_API_KEY;
const SUPABASE_URL = process.env.SUPABASE_URL;
// Production URL from Config.swift
const PRODUCTION_URL = "https://mysocialcookbook-production.up.railway.app";

if (!API_KEY) {
    console.error("❌ Error: GEMINI_API_KEY not found in backend/.env");
    process.exit(1);
}

const genAI = new GoogleGenerativeAI(API_KEY);
const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" });

async function checkHealth() {
    const healthStatus: Record<string, any> = {
        production_backend: { status: "unknown", details: "" },
        supabase: { status: "unknown", details: "" },
        gemini: { status: "unknown", details: "" }
    };

    // 1. Check Production Backend (Railway)
    try {
        const response = await fetch(PRODUCTION_URL);
        if (response.ok) {
            healthStatus.production_backend = { status: "healthy", details: "Railway production server is up and responding." };
        } else {
            healthStatus.production_backend = { status: "unhealthy", details: `Server returned status ${response.status}` };
        }
    } catch (e: any) {
        healthStatus.production_backend = { status: "down", details: e.message };
    }

    // 2. Check Supabase
    if (SUPABASE_URL) {
        try {
            // Pinging the health endpoint if accessible, or just the root
            const response = await fetch(`${SUPABASE_URL}/rest/v1/`, {
                headers: { apikey: process.env.SUPABASE_ANON_KEY || "" }
            });
            if (response.status === 200 || response.status === 401) { // 401 means reachable but requires auth
                healthStatus.supabase = { status: "healthy", details: "Supabase API is reachable" };
            } else {
                healthStatus.supabase = { status: "unhealthy", details: `Supabase returned status ${response.status}` };
            }
        } catch (e: any) {
            healthStatus.supabase = { status: "down", details: e.message };
        }
    }

    // 3. Check Gemini
    try {
        const testModel = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
        await testModel.generateContent("ping");
        healthStatus.gemini = { status: "healthy", details: "Gemini API is active and responding to requests." };
    } catch (e: any) {
        healthStatus.gemini = { status: "unhealthy", details: e.message };
    }

    return healthStatus;
}

async function getRecentDiffs() {
    try {
        // Check for commits in the last 15 minutes
        const commits = execSync('git log --since="15 minutes ago" --pretty=format:"%H"').toString().trim();

        if (!commits) {
            console.log("🤠 Sheriff: Stillness in the town. No new code trails found.");
            return { diff: null, hashes: [] };
        }

        const commitList = commits.split("\n");
        console.log(`🤠 Sheriff: Found ${commitList.length} recent commits. Auditing now...`);

        // Get the full diff of these commits against their parent(s)
        const diff = execSync(`git diff ${commitList[commitList.length - 1]}~1 ${commitList[0]}`).toString();
        return { diff, hashes: commitList };
    } catch (error) {
        console.error("🤠 Sheriff: Error reading the git trails:", error);
        return { diff: null, hashes: [] };
    }
}

async function runSheriffAudit() {
    console.log("🤠 Sheriff: Initiating production patrol...");

    const health = await checkHealth();
    const data = await getRecentDiffs();

    const { diff, hashes } = data;
    const truncatedDiff = diff ? (diff.length > 60000 ? diff.substring(0, 60000) + "\n... [Audit truncated due to size]" : diff) : "No changes detected.";

    const protocolPath = path.resolve(process.cwd(), ".agent", "workflows", "review_and_push.md");
    const protocol = fs.existsSync(protocolPath) ? fs.readFileSync(protocolPath, "utf-8") : "Standard Council Review Protocol";

    const prompt = `
# 🤠 SHERIFF AGENT AUDIT & HEALTH REPORT

You are the **Sheriff Agent**. You audit the **Production Health** and enforce the **Review & Push Protocol**. 
There are no local servers; everything is in the cloud (Railway + Supabase).

## 🏥 PRODUCTION HEALTH STATUS:
${JSON.stringify(health, null, 2)}

## 📜 THE PROTOCOL:
\`\`\`markdown
${protocol}
\`\`\`

## 🔍 RECENT CODE CHANGES:
\`\`\`diff
${truncatedDiff}
\`\`\`

## YOUR MISSION:
1. Report on **Production Health**. Identify if Railway or Supabase are having issues.
2. If there are code changes:
   - Perform a "Council Review" (Architect, Risk-team, Testing, Perfectionist).
   - Ensure "Zero Orphans" logic is followed.
3. If no code changes:
   - Provide a brief "Quiet Town" report focusing on health.
4. Output a Markdown assessment.

### Output Format:
# 🤠 Sheriff's Report - $(new Date().toLocaleString())

## 🏥 Health Audit
| Service | Status | Details |
| :--- | :--- | :--- |
| Production Backend | [Status] | [Details] |
| Supabase | [Status] | [Details] |
| Gemini | [Status] | [Details] |

[Brief health commentary]

## 🏛 Code Audit (Protocol Enforcement)
| Persona | Verdict | Sheriff's Notes | Verified? |
| :--- | :--- | :--- | :--- |
| **Architect** | [Pass/Fail/N/A] | [Reasoning] | [✅/❌/➖] |
| **Risk-team** | [Pass/Fail/N/A] | [Reasoning] | [✅/❌/➖] |
| **Testing** | [Pass/Fail/N/A] | [Reasoning] | [✅/❌/➖] |
| **The-perfectionist** | [Pass/Fail/N/A] | [Reasoning] | [✅/❌/➖] |

**Sheriff's Verdict:** [CLEAN / CRIME COMMITTED / QUIET TOWN]
**Action Items:** [List if any]
`;

    console.log("🤠 Sheriff: Evaluating the cloud health and code changes...");
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    const auditPath = path.resolve(process.cwd(), ".agent", "sheriff_audit.md");
    fs.writeFileSync(auditPath, text);

    console.log("\n--- SHERIFF'S AUDIT REPORT ---\n");
    console.log(text);
    console.log(`\nAudit saved to ${auditPath}`);

    if (hashes.length > 0) {
        try {
            const latestHash = hashes[0];
            const commentFile = path.resolve(process.cwd(), ".agent", "sheriff_comment.md");
            fs.writeFileSync(commentFile, `### 🤠 Sheriff Agent Audit Result\n\n${text}`);
        } catch (e) { }
    }
}

runSheriffAudit();
