import { GoogleGenerativeAI } from "@google/generative-ai";
import { execSync } from "child_process";
import * as dotenv from "dotenv";
import * as path from "path";
import * as fs from "fs";

// Load environment variables from backend/.env
const backendEnvPath = path.resolve(process.cwd(), "backend", ".env");
if (fs.existsSync(backendEnvPath)) {
    dotenv.config({ path: backendEnvPath });
}

const API_KEY = process.env.GEMINI_API_KEY;
if (!API_KEY) {
    console.error("❌ Error: GEMINI_API_KEY not found in backend/.env");
    process.exit(1);
}

const genAI = new GoogleGenerativeAI(API_KEY);
const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" }); // Fast and capable

async function getRecentDiffs() {
    try {
        // Get commits from the last 15 minutes
        const commits = execSync('git log --since="15 minutes ago" --pretty=format:"%H"').toString().trim();

        if (!commits) {
            console.log("No new commits in the last 15 minutes.");
            return null;
        }

        const commitList = commits.split("\n");
        console.log(`Found ${commitList.length} recent commits. Analyzing diff...`);

        // Get the full diff of these commits against their parents
        const diff = execSync(`git diff ${commitList[commitList.length - 1]}~1 ${commitList[0]}`).toString();
        return diff;
    } catch (error) {
        console.error("Error fetching git diffs:", error);
        return null;
    }
}

async function runReview() {
    const diff = await getRecentDiffs();
    if (!diff) return;

    // Truncate diff if it's too large (Gemini has a large context but let's be safe)
    const truncatedDiff = diff.length > 50000 ? diff.substring(0, 50000) + "\n... [Diff truncated due to size]" : diff;

    const prompt = `
# 📜 Review & Push Protocol - Automated Evaluation

You are an AI Review Agent. Your task is to evaluate the following code changes (git diff) against our project's "Council Review" protocol.

## Protocol Context:
- **Architect**: Alignment with project structure and long-term goals.
- **Risk-team**: Security, performance, breaking changes.
- **Testing**: Test coverage and edge cases.
- **The-perfectionist**: Clean code, formatting, no typos, no "orphan" words in UI.

## The Diff:
\`\`\`diff
${truncatedDiff}
\`\`\`

## Your Task:
1. Analyze the changes.
2. Generate a Markdown "Council Review Table" as follows:

| Persona | Analysis & Feedback | Verified? |
| :--- | :--- | :--- |
| **Architect** | [Your feedback] | [✅ or ❌] |
| **Risk-team** | [Your feedback] | [✅ or ❌] |
| **Testing** | [Your feedback] | [✅ or ❌] |
| **The-perfectionist** | [Your feedback] | [✅ or ❌] |

3. Provide a summary of "Critical Actions" if any ❌ are present.
4. Keep feedback direct and actionable. Use a professional but friendly tone.

Return ONLY the markdown table and summary.
`;

    console.log("Sending diff to Gemini for review...");
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    const reportPath = path.resolve(process.cwd(), ".agent", "latest_review.md");
    fs.writeFileSync(reportPath, text);

    console.log("\n--- REVIEW RESULT ---\n");
    console.log(text);
    console.log(`\nReport saved to ${reportPath}`);

    // Optional: Post to GitHub if gh is available
    try {
        const isGitRepo = execSync('git rev-parse --is-inside-work-tree').toString().trim() === 'true';
        if (isGitRepo) {
            // Create a temporary file for the comment
            const commentFile = path.resolve(process.cwd(), ".agent", "gh_comment.md");
            fs.writeFileSync(commentFile, `### 🤖 Automated Review for Recent Pushes\n\n${text}`);

            // Attempt to comment on the latest commit using gh
            const latestHash = execSync('git rev-parse HEAD').toString().trim();
            // execSync(`gh commit-comment create ${latestHash} --body-file ${commentFile}`);
            // console.log(`Posted review to GitHub commit ${latestHash}`);
        }
    } catch (e) {
        console.warn("Could not post to GitHub (maybe no remote or gh not authenticated).");
    }
}

runReview();
