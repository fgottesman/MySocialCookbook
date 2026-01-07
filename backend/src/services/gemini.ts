
import { GoogleGenerativeAI } from "@google/generative-ai";
import { GoogleAIFileManager } from "@google/generative-ai/server";
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

const PROMPT_TO_RECIPE_SYSTEM_PROMPT = `
You are an expert chef. A user will describe a dish they want to make.
Your goal is to turn their description into a fully fleshed out, professional recipe.
If the description is vague, use your culinary expertise to fill in the gaps (e.g., if they say "grilled cheese", decide on the best bread, cheese, and technique).

Return ONLY a raw JSON object (no markdown formatting) with this schema:
{
  "title": "Recipe Title",
  "description": "Short, appetizing description of the dish",
  "ingredients": [
    { "name": "item", "amount": "1", "unit": "cup" }
  ],
  "instructions": ["Step 1", "Step 2"],
  "chefsNote": "A quick tip from the chef about this specific dish"
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
5.  **Track Changed Ingredients:** List the NAMES of all ingredients that were changed, added, or substituted in the "changedIngredients" array. Use the new ingredient name (not the original).

## 3. Output Format
Return ONLY valid JSON matching the Recipe schema.

{
  "title": "Modified Recipe Name",
  "description": "Updated description mentioning the remix.",
  "ingredients": [ ... ],
  "instructions": [ ... ],
  "chefsNote": "Detailed explanation of the changes...",
  "changedIngredients": ["ingredient1 name", "ingredient2 name"]
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

const STEP_PREPARATION_PROMPT = `
**Role:** You are a friendly Sous Chef helping prepare a cook for their next step. Analyze the step and provide structured guidance.

## Your Tasks:

### 1. Introduction (REQUIRED)
Write a brief, warm introduction for this step. It will be read aloud via TTS.
- Keep it to 1-2 sentences
- Be encouraging and helpful
- Explain WHAT they're about to do and briefly WHY (if relevant)
- No markdown, write naturally for speech
- Example: "Alright, let's get those vegetables ready! We're going to dice them into small cubes so they cook evenly."

### 2. Sub-Steps (CONDITIONAL)
If the step contains MULTIPLE DISTINCT ACTIONS (connected by "then", "and then", "after that", or containing comma-separated major tasks), break it into sub-steps.
- Only break down if there are genuinely separate actions
- Each sub-step should be a single clear action
- Keep the original wording where possible, just separated
- If the step is already simple and focused, return null for subSteps

### 3. Measurements & Conversions (CONDITIONAL)
Scan the step for any measurements (cups, tablespoons, teaspoons, ounces, pounds, Fahrenheit, etc.).
For each measurement found:
- Provide the metric equivalent (grams, ml, Celsius)
- Provide a natural spoken version of the conversion
- If no measurements found, return null for conversions

## Output Format
Return ONLY valid JSON matching this schema (no markdown):
{
  "introduction": "Your warm, spoken introduction to the step",
  "subSteps": [
    { "label": "1-a", "text": "First action" },
    { "label": "1-b", "text": "Second action" }
  ] | null,
  "conversions": [
    { 
      "original": "1 cup flour", 
      "metric": "125g flour",
      "imperial": "1 cup flour", 
      "spoken": "One cup of flour is about 125 grams"
    }
  ] | null
}
`;

export class GeminiService {

    async uploadMedia(path: string, mimeType: string = "video/mp4") {
        const uploadResult = await fileManager.uploadFile(path, {
            mimeType,
            displayName: "Social Recipe Media",
        });

        console.log(`Uploaded file ${uploadResult.file.displayName} as: ${uploadResult.file.uri} (${mimeType})`);
        return uploadResult.file;
    }

    async chatCompanion(recipe: any, currentStepIndex: number, chatHistory: any[], userMessage: string) {
        const model = genAI.getGenerativeModel({ model: "gemini-3-flash-preview" });

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
     * Prepare a step for cooking mode.
     * Analyzes the step, generates an introduction, breaks down compound steps,
     * and provides measurement conversions.
     */
    async prepareStep(recipe: any, stepIndex: number, stepLabel: string = "1") {
        const model = genAI.getGenerativeModel({ model: "gemini-3-flash-preview" });

        const instructions = recipe.instructions || [];
        const currentStep = instructions[stepIndex] || "";

        const FULL_PROMPT = `
        ${STEP_PREPARATION_PROMPT}

        CONTEXT:
        Recipe Title: ${recipe.title}
        Step Number: ${stepIndex + 1}
        Step Label for Sub-Steps: "${stepLabel}" (use "${stepLabel}-a", "${stepLabel}-b", etc.)
        
        INGREDIENTS (scan these for measurements to offer conversions):
        ${JSON.stringify(recipe.ingredients || [])}
        
        CURRENT STEP TO ANALYZE:
        "${currentStep}"
        `;

        const result = await model.generateContent(FULL_PROMPT);
        return this.parseStepPreparation(result.response.text());
    }

    private parseStepPreparation(responseText: string) {
        console.log("Raw step preparation response:", responseText);

        const firstBrace = responseText.indexOf('{');
        const lastBrace = responseText.lastIndexOf('}');

        if (firstBrace === -1 || lastBrace === -1) {
            // Fallback if no JSON found - return minimal response
            return {
                introduction: "Let's get started on this step.",
                subSteps: null,
                conversions: null
            };
        }

        const jsonText = responseText.substring(firstBrace, lastBrace + 1);
        try {
            return JSON.parse(jsonText);
        } catch (e) {
            console.error("Failed to parse step preparation JSON:", e);
            return {
                introduction: "Let's get started on this step.",
                subSteps: null,
                conversions: null
            };
        }
    }

    /**
     * Transcribe audio to text using Gemini 3 Flash.
     * Accepts base64 encoded audio data.
     */
    async transcribeAudio(audioBase64: string, mimeType: string = 'audio/webm') {
        const model = genAI.getGenerativeModel({ model: "gemini-3-flash-preview" });

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

    async generateRecipe(fileUri: string, mimeType: string = "video/mp4", description?: string) {
        const model = genAI.getGenerativeModel({ model: "gemini-3-flash-preview" });

        let prompt = RECIPE_PROMPT;
        if (description) {
            prompt += `\n\nCONTEXT FROM POST CAPTION/DESCRIPTION:\n${description}\n\nUse this context to ensure ingredient amounts and names are accurate.`;
        }

        const result = await model.generateContent([
            {
                fileData: {
                    mimeType: mimeType,
                    fileUri: fileUri,
                },
            },
            { text: prompt },
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
        const model = genAI.getGenerativeModel({ model: "gemini-3-flash-preview" });

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

        const model = genAI.getGenerativeModel({ model: "gemini-3-flash-preview" });

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
        const model = genAI.getGenerativeModel({ model: "gemini-3-flash-preview" })

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

    async generateRecipeFromPrompt(userPrompt: string) {
        const model = genAI.getGenerativeModel({ model: "gemini-3-flash-preview" });

        const FULL_PROMPT = `
        ${PROMPT_TO_RECIPE_SYSTEM_PROMPT}

        USER DESCRIPTION:
        "${userPrompt}"
        `;

        const result = await model.generateContent(FULL_PROMPT);
        return this.parseRecipeResponse(result.response.text());
    }

    private parseRecipeResponse(responseText: string) {
        console.log("Raw Gemini response:", responseText);

        // Find the first '{' and the last '}'
        const firstBrace = responseText.indexOf('{');
        const lastBrace = responseText.lastIndexOf('}');

        if (firstBrace === -1 || lastBrace === -1) {
            throw new Error("No JSON object found in Gemini response");
        }

        const jsonText = responseText.substring(firstBrace, lastBrace + 1);
        return JSON.parse(jsonText);
    }

    async generateEmbedding(text: string) {
        const model = genAI.getGenerativeModel({ model: "text-embedding-004" });
        const result = await model.embedContent(text);
        return result.embedding.values;
    }

    /**
     * Generate a food image for a recipe using Gemini's image generation (Nano Banana).
     * Returns base64 encoded image data.
     */
    async generateFoodImage(recipeTitle: string, description?: string): Promise<string | null> {
        try {
            // Use Gemini 2.5 Flash for image generation (Nano Banana)
            const model = genAI.getGenerativeModel({
                model: "gemini-2.5-flash-preview-native-image"
            });

            const imagePrompt = `Generate a stunning, appetizing food photograph of: "${recipeTitle}"
            
Style guidelines:
- Professional food photography, overhead or 45-degree angle shot
- Beautiful plating on a rustic wooden table or marble surface
- Soft natural lighting, slightly warm tones
- Garnished elegantly, restaurant quality presentation
- Shallow depth of field with bokeh background
- Include complementary props like fresh herbs, ingredients, or elegant utensils
${description ? `\nDish description: ${description}` : ''}

Make it look absolutely delicious and instagram-worthy.`;

            // Use simple text prompt - the model will generate image content
            const result = await model.generateContent(imagePrompt);

            // Extract image from response
            const response = result.response;
            const parts = response.candidates?.[0]?.content?.parts || [];

            for (const part of parts) {
                // Check for inline image data
                const partAny = part as any;
                if (partAny.inlineData?.data) {
                    console.log("Generated food image successfully");
                    return partAny.inlineData.data; // base64 encoded image
                }
            }

            console.log("No image data in response - model may not support image generation");
            return null;
        } catch (error: any) {
            console.error("Error generating food image:", error.message);
            return null;
        }
    }
}
