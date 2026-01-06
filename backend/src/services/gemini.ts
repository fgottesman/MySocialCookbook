
import { GoogleGenerativeAI } from "@google/generative-ai";
import { GoogleAIFileManager } from "@google/generative-ai/files";
import fs from 'fs';

const apiKey = process.env.GEMINI_API_KEY;
const genAI = new GoogleGenerativeAI(apiKey || "");
const fileManager = new GoogleAIFileManager(apiKey || "");

const RECIPE_PROMPT = `
You are an expert chef. Extract the recipe from this cooking video.
Return ONLY a raw JSON object (no markdown formatting) with this schema:
{
  "title": "Recipe Title",
  "description": "Short description",
  "ingredients": [
    { "name": "item", "amount": "1", "unit": "cup" }
  ],
  "instructions": ["Step 1", "Step 2"]
}
`;

const REMIX_SYSTEM_PROMPT = `
**Role:** You are a World-Class Michelin Star Sous-Chef and Food Scientist. Your goal is to modify recipes based on user requests while maintaining culinary integrity, flavor balance, and food safety.

## 1. Core Directives
*   **Safety First:** If a user request is dangerous (e.g., "cook chicken to 100F", "add bleach"), REFUSE firmly and explaining why.
*   **Edibility Check:** Only process requests related to food. If a user asks to "remix" non-food items, politely decline.
*   **Logic & Ratio:** When scaling or substituting, you must adjust *all* related components.
    *   *Example:* If changing "Chicken" to "Tofu", you must also update cooking times (Tofu cooks faster) and seasoning technique (Tofu needs more marinade).
*   **Tone:** Helpful, authoritative, widely knowledgeable, and encouraging.

## 2. Remix Logic
When you receive a originalRecipe JSON and a userPrompt:

1.  **Analyze the Request:** Determine the intent (Substitution, Scaling, Diet, Flavor Twist).
2.  **Modify Ingredients:**
    *   Swap items intelligently (e.g., "Butter" -> "Coconut Oil" for vegan).
    *   Recalculate quantities for scaling.
3.  **Rewrite Instructions:**
    *   **CRITICAL:** You must rewrite the steps to match the new ingredients. Do not leave "sear the steak" if the user swapped to "tofu".
    *   Update timestamps/durations.
4.  **Add "Chef's Note":** Add a specific note explaining *why* you made certain changes (e.g., "I swapped sugar for honey, so I lowered the oven temp slightly to prevent burning.").

## 3. Output Format
Return ONLY valid JSON matching the Recipe schema.

{
  "title": "Modified Recipe Name",
  "description": "Updated description mentioning the remix.",
  "ingredients": [ ... ],
  "instructions": [ ... ],
  "chefsNote": "Detailed explanation of the changes..."
}
`;


const VOICE_COMPANION_PROMPT = `
**Role:** You are a friendly, calm, and concise Sous Chef assisting a user who is currently cooking. Your output will be read aloud via Text-to-Speech (TTS), so you must write for the ear, not the eye.

## 1. Core Directives
*   **Concise is King:** Keep answers short (1-2 sentences maximum) unless a detailed explanation is requested. The user is busy and hands-full.
*   **No Markdown:** Do not use bold, italics, or lists. Use natural speech patterns.
*   **Context Aware:** You are given the currentStep and the recipe. Use this context to answer specific questions like "What do I do next?".
*   **Tone:** Calm, encouraging, authoritative but warm. Like a helpful friend in the kitchen.

## 2. Output
Return a clean text string of what you want to say back to the user.
`;

export class GeminiService {

    async uploadVideo(path: string, mimeType: string = "video/mp4") {
        const uploadResult = await fileManager.uploadFile(path, {
            mimeType,
            displayName: "Social Recipe Video",
        });

        console.log(`Uploaded file ${uploadResult.file.displayName} as: ${uploadResult.file.uri}`);
        return uploadResult.file;
    }

    async chatCompanion(recipe: any, currentStepIndex: number, chatHistory: any[], userMessage: string) {
        const model = genAI.getGenerativeModel({ model: "gemini-3-flash" });

        const historyContext = chatHistory.map(msg =>
            `${msg.role === 'user' ? 'User' : 'AI'}: ${msg.content}`
        ).join('\n');

        const FULL_PROMPT = `
        ${VOICE_COMPANION_PROMPT}

        CONTEXT:
        Recipe: ${JSON.stringify(recipe)}
        Current Step Index: ${currentStepIndex}
        
        CHAT HISTORY:
        ${historyContext}

        USER MESSAGE:
        "${userMessage}"
        `;

        const result = await model.generateContent(FULL_PROMPT);
        return result.response.text();
    }

    /**
     * Transcribe audio to text using Gemini 3 Flash.
     * Accepts base64 encoded audio data.
     */
    async transcribeAudio(audioBase64: string, mimeType: string = 'audio/webm') {
        const model = genAI.getGenerativeModel({ model: "gemini-3-flash" });

        const result = await model.generateContent([
            {
                inlineData: {
                    mimeType: mimeType,
                    data: audioBase64
                }
            },
            { text: "Transcribe this audio exactly. Return ONLY the transcribed text, nothing else. No quotes, no explanations." }
        ]);

        return result.response.text().trim();
    }

    async waitForProcessing(fileName: string) {
        let file = await fileManager.getFile(fileName);
        while (file.state === "PROCESSING") {
            process.stdout.write(".");
            await new Promise((resolve) => setTimeout(resolve, 2000));
            file = await fileManager.getFile(fileName);
        }
        console.log(`File state: ${file.state} `);
        return file;
    }

    async generateRecipe(fileUri: string) {
        const model = genAI.getGenerativeModel({ model: "gemini-3-flash" });

        const result = await model.generateContent([
            {
                fileData: {
                    mimeType: "video/mp4",
                    fileUri: fileUri,
                },
            },
            { text: RECIPE_PROMPT },
        ]);

        return this.parseRecipeResponse(result.response.text());
    }

    /**
     * Process a YouTube video directly via URL using file_uri format.
     * The Gemini API supports YouTube URLs as file_uri for multimodal analysis.
     */
    async generateRecipeFromYouTube(youtubeUrl: string) {
        console.log("Processing YouTube video directly:", youtubeUrl);

        // Use gemini-3-flash which has better YouTube support
        const model = genAI.getGenerativeModel({ model: "gemini-3-flash" });

        const result = await model.generateContent([
            {
                fileData: {
                    mimeType: "video/mp4",
                    fileUri: youtubeUrl,  // YouTube URLs work as file_uri
                },
            },
            { text: RECIPE_PROMPT },
        ]);

        return this.parseRecipeResponse(result.response.text());
    }

    /**
     * Attempt to process any social media URL directly via Gemini.
     * Works for YouTube, may work for other platforms.
     * If this fails, caller should fall back to download approach.
     */
    async generateRecipeFromURL(url: string) {
        console.log("Attempting direct URL processing:", url);

        const model = genAI.getGenerativeModel({ model: "gemini-3-flash" });

        const result = await model.generateContent([
            {
                fileData: {
                    mimeType: "video/mp4",
                    fileUri: url,
                },
            },
            { text: RECIPE_PROMPT },
        ]);

        return this.parseRecipeResponse(result.response.text());

    }

    async remixRecipe(originalRecipe: any, userPrompt: string) {
        const model = genAI.getGenerativeModel({ model: "gemini-3-flash" })

        const REMIX_PROMPT = `
        ${REMIX_SYSTEM_PROMPT}

        ORIGINAL RECIPE:
        ${JSON.stringify(originalRecipe)}

        USER REQUEST:
"${userPrompt}"
    `

        const result = await model.generateContent(REMIX_PROMPT);
        return this.parseRecipeResponse(result.response.text());
    }

    private parseRecipeResponse(responseText: string) {
        console.log("Raw Gemini response:", responseText);
        // Cleanup potential markdown blocks
        const cleanedText = responseText.replace(/```json/g, "").replace(/```/g, "").trim();
        return JSON.parse(cleanedText);
    }

    async generateEmbedding(text: string) {
        const model = genAI.getGenerativeModel({ model: "text-embedding-004" });
        const result = await model.embedContent(text);
        return result.embedding.values;
    }
}
