import { GoogleGenerativeAI } from "@google/generative-ai";
import { GoogleAIFileManager } from "@google/generative-ai/server";
import fs from 'fs';
import { AI_MODELS } from '../config/ai_models';
import { withRetry } from '../utils/retry';
import logger from '../utils/logger';

const apiKey = process.env.GEMINI_API_KEY;
const genAI = new GoogleGenerativeAI(apiKey || "");
const fileManager = new GoogleAIFileManager(apiKey || "");

// User preferences interface for recipe generation
export interface RecipePreferences {
    unitSystem?: 'imperial' | 'metric';
    prepStyle?: 'just_in_time' | 'prep_first';
    defaultServings?: number;
    dietaryRestrictions?: string[];
    otherPreferences?: string;
}

// Helper to build preference instructions for prompts
const buildPreferenceInstructions = (preferences?: RecipePreferences): string => {
    const instructions: string[] = [];

    // Unit system
    if (preferences?.unitSystem === 'metric') {
        instructions.push('IMPORTANT: Use METRIC measurements throughout (grams, milliliters, Celsius). Convert any imperial measurements to metric.');
    } else {
        instructions.push('Use imperial measurements (cups, tablespoons, teaspoons, ounces, Fahrenheit).');
    }

    // Default servings
    if (preferences?.defaultServings && preferences.defaultServings > 0) {
        instructions.push(`Scale the recipe to serve ${preferences.defaultServings} people.`);
    }

    // Dietary restrictions
    if (preferences?.dietaryRestrictions && preferences.dietaryRestrictions.length > 0) {
        const restrictions = preferences.dietaryRestrictions.join(', ');
        instructions.push(`IMPORTANT DIETARY RESTRICTIONS: The user follows these dietary requirements: ${restrictions}. You MUST adapt the recipe to comply with these restrictions. Substitute any non-compliant ingredients with appropriate alternatives.`);
    }

    // Other preferences
    if (preferences?.otherPreferences && preferences.otherPreferences.trim()) {
        instructions.push(`ADDITIONAL USER PREFERENCES: ${preferences.otherPreferences.trim()}`);
    }

    return instructions.join('\n');
};

const getRecipePrompt = (preferences?: RecipePreferences) => {
    const preferenceInstructions = buildPreferenceInstructions(preferences);

    return `
You are an expert chef. Extract the recipe from this cooking video.

USER PREFERENCES:
${preferenceInstructions}

Return ONLY a raw JSON object (no markdown formatting) with this schema:
{
  "title": "Recipe Title",
  "description": "Short description",
  "difficulty": "Easy",
  "cookingTime": "30-45 minutes",
  "ingredients": [
    { "name": "item", "amount": "1", "unit": "${preferences?.unitSystem === 'metric' ? 'g' : 'cup'}" }
  ],
  "instructions": ["Step 1", "Step 2"],
  "step0Summary": "A brief, enthusiastic 1-2 sentence summary of what we are cooking for voice over."
}
`;
};

const getWebRecipePrompt = (preferences?: RecipePreferences) => {
    const preferenceInstructions = buildPreferenceInstructions(preferences);

    return `
You are an expert chef. Extract and structure the recipe from this web page content.
The content may include structured data from the page and/or raw text extracted from the page.

Your task:
1. Identify the recipe in the content
2. Extract all ingredients with their amounts and units
3. Extract clear, step-by-step cooking instructions
4. Determine difficulty level based on techniques and time required
5. Estimate total cooking time if not explicitly stated

USER PREFERENCES:
${preferenceInstructions}

Return ONLY a raw JSON object (no markdown formatting) with this schema:
{
  "title": "Recipe Title",
  "description": "Short, appetizing description of the dish",
  "difficulty": "Easy" | "Medium" | "Hard",
  "cookingTime": "30-45 minutes",
  "ingredients": [
    { "name": "item", "amount": "1", "unit": "${preferences?.unitSystem === 'metric' ? 'g' : 'cup'}" }
  ],
  "instructions": ["Step 1", "Step 2"],
  "chefsNote": "A helpful tip about this dish or a key technique to master",
  "step0Summary": "A brief, enthusiastic 1-2 sentence summary of what we are cooking for voice over."
}

Important:
- Ensure ingredient amounts are properly parsed (e.g., "1 1/2 cups" should be amount: "1 1/2", unit: "cups")
- Instructions should be clear, actionable steps (not paragraph blocks)
- If the recipe has many instructions, consolidate related steps where sensible
- Difficulty: Easy (< 30 min, basic techniques), Medium (30-60 min or intermediate techniques), Hard (> 60 min or advanced techniques)
`;
};

const getPromptToRecipePrompt = (preferences?: RecipePreferences) => {
    const preferenceInstructions = buildPreferenceInstructions(preferences);

    return `
You are an expert chef. A user will describe a dish they want to make.
Your goal is to turn their description into a fully fleshed out, professional recipe.
If the description is vague, use your culinary expertise to fill in the gaps (e.g., if they say "grilled cheese", decide on the best bread, cheese, and technique).

USER PREFERENCES:
${preferenceInstructions}

Return ONLY a raw JSON object (no markdown formatting) with this schema:
{
  "title": "Recipe Title",
  "description": "Short, appetizing description of the dish",
  "difficulty": "Easy",
  "cookingTime": "30-45 minutes",
  "ingredients": [
    { "name": "item", "amount": "1", "unit": "${preferences?.unitSystem === 'metric' ? 'g' : 'cup'}" }
  ],
  "instructions": ["Step 1", "Step 2"],
  "chefsNote": "A quick tip from the chef about this specific dish",
  "step0Summary": "A brief, enthusiastic 1-2 sentence summary of what we are cooking for voice over."
}
`;
};

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
  "difficulty": "Easy",
  "cookingTime": "30-45 minutes",
  "ingredients": [ ... ],
  "instructions": [ ... ],
  "chefsNote": "Detailed explanation of the changes...",
  "changedIngredients": ["ingredient1 name", "ingredient2 name"],
  "step0Summary": "A brief, enthusiastic 1-2 sentence summary of HOW we are going to cook the REMIXED dish. Focus on the method (e.g., 'We're going to sear the steak in a hot skillet then finish it with butter', not just 'Great steak')."
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

const REMIX_CONSULT_SYSTEM_PROMPT = `
**Role:** You are a Michelin Star Chef and Food Scientist. You are discussing a potential recipe remix with a user.
Your goal is to propose a SPECIFIC, ACTIONABLE plan for the changes they requested.

## 1. Critical Rules
*   **BE DECISIVE:** Do NOT offer multiple options or ask which approach the user prefers. Pick the BEST approach and commit to it.
*   **STATE YOUR PLAN CLEARLY:** Tell the user exactly what you WILL change when they confirm. Example: "I'll swap the turkey for roasted wild mushrooms and add extra seasoning to balance the flavors."
*   **BE CONCISE:** Keep your response to 3-5 sentences maximum. No long explanations.
*   **NO QUESTIONS:** Do not end with questions like "Would you like to try this?" or "Should we use X or Y?" Just state what you'll do.

## 2. Analysis (Internal - inform your response)
Evaluate quickly:
*   **Difficulty:** Will this make the recipe harder, easier, or the same?
*   **Quality:** How will this affect the flavor or enjoyment?

## 3. Response Style
*   State your specific plan in 1-2 sentences
*   Mention one key benefit or tip if relevant
*   That's it - short and decisive

## 4. Output Format
Return ONLY a raw JSON object (no markdown) with this schema:
{
  "reply": "Your brief, decisive response stating exactly what you'll change. No options, no questions. 3-5 sentences max.",
  "difficultyImpact": "Harder" | "Easier" | "Same",
  "difficultyExplanation": "Brief explanation of difficulty change.",
  "qualityImpact": "Better" | "Worse" | "Different" | "Debatable",
  "qualityExplanation": "Brief explanation of quality change.",
  "canProceed": true // Set to false if the request is impossible or dangerous
}
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

        logger.info(`Uploaded file ${uploadResult.file.displayName} as: ${uploadResult.file.uri} (${mimeType})`);
        return uploadResult.file;
    }

    async chatCompanion(recipe: any, currentStepIndex: number, chatHistory: any[], userMessage: string) {
        const model = genAI.getGenerativeModel({ model: AI_MODELS.RECIPE_ENGINE });

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

        const result = await withRetry(() => model.generateContent(FULL_PROMPT), {}, 'Gemini: chatCompanion');
        return result.response.text();
    }

    /**
     * Prepare a step for cooking mode.
     * Analyzes the step, generates an introduction, breaks down compound steps,
     * and provides measurement conversions.
     */
    async prepareStep(recipe: any, stepIndex: number, stepLabel: string = "1") {
        const model = genAI.getGenerativeModel({ model: AI_MODELS.RECIPE_ENGINE });

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

        const result = await withRetry(() => model.generateContent(FULL_PROMPT), {}, 'Gemini: prepareStep');
        return this.parseStepPreparation(result.response.text());
    }

    private parseJsonFromResponse(responseText: string) {
        const firstBrace = responseText.indexOf('{');
        const lastBrace = responseText.lastIndexOf('}');

        if (firstBrace === -1 || lastBrace === -1) {
            return null;
        }

        const jsonText = responseText.substring(firstBrace, lastBrace + 1);
        try {
            return JSON.parse(jsonText);
        } catch (e) {
            logger.error("Failed to parse JSON from response", { error: e, text: jsonText.substring(0, 100) });
            return null;
        }
    }

    private parseStepPreparation(responseText: string) {
        const data = this.parseJsonFromResponse(responseText);
        return data || {
            introduction: "Let's get started on this step.",
            subSteps: null,
            conversions: null
        };
    }
    /**
     * Pre-compute step preparations for all steps in a recipe.
     * Called at recipe creation time for instant loading in cooking mode.
     */
    async prepareAllSteps(recipe: any): Promise<any[]> {
        const instructions = recipe.instructions || [];
        if (instructions.length === 0) return [];

        logger.info(`Pre-computing ${instructions.length} step preparations for: ${recipe.title}`);

        // Process all steps in parallel
        const preparations = await Promise.all(
            instructions.map(async (_: string, index: number) => {
                try {
                    return await this.prepareStep(recipe, index, String(index + 1));
                } catch (error) {
                    logger.error(`Failed to prepare step ${index}`, error);
                    return {
                        introduction: `Let's work on step ${index + 1}.`,
                        subSteps: null,
                        conversions: null
                    };
                }
            })
        );

        logger.info(`Pre-computed ${preparations.length} step preparations`);
        return preparations;
    }

    /**
     * Transcribe audio to text using Gemini 3 Flash.
     * Accepts base64 encoded audio data.
     */
    async transcribeAudio(audioBase64: string, mimeType: string = 'audio/webm') {
        const model = genAI.getGenerativeModel({ model: AI_MODELS.RECIPE_ENGINE });

        const result = await withRetry(() => model.generateContent([
            {
                inlineData: {
                    mimeType: mimeType,
                    data: audioBase64
                }
            },
            { text: "Transcribe this audio exactly. Return ONLY the transcribed text, nothing else. No quotes, no explanations." }
        ]), {}, 'Gemini: transcribeAudio');

        return result.response.text().trim();
    }

    async waitForProcessing(fileName: string) {
        let file = await fileManager.getFile(fileName);
        while (file.state === "PROCESSING") {
            process.stdout.write(".");
            await new Promise((resolve) => setTimeout(resolve, 2000));
            file = await fileManager.getFile(fileName);
        }
        logger.debug(`File state: ${file.state}`);
        return file;
    }

    async generateRecipe(localPath: string, mimeType: string = "video/mp4", description?: string, preferences?: RecipePreferences) {
        const model = genAI.getGenerativeModel({ model: AI_MODELS.RECIPE_ENGINE });

        logger.info(`Uploading file to Gemini: ${localPath} (${mimeType})`);
        // 1. Upload to Google File API
        const uploadedFile = await this.uploadMedia(localPath, mimeType);

        // 2. Wait for processing to complete
        await this.waitForProcessing(uploadedFile.name);

        logger.info(`File processed. Generating recipe from: ${uploadedFile.uri} (unitSystem: ${preferences?.unitSystem || 'imperial'})`);

        let prompt = getRecipePrompt(preferences);
        if (description) {
            prompt += `\n\nCONTEXT FROM POST CAPTION/DESCRIPTION:\n${description}\n\nUse this context to ensure ingredient amounts and names are accurate.`;
        }

        const result = await withRetry(() => model.generateContent([
            {
                fileData: {
                    mimeType: mimeType,
                    fileUri: uploadedFile.uri, // Use the Remote URI
                },
            },
            { text: prompt },
        ]), {}, 'Gemini: generateRecipe');

        return this.parseRecipeResponse(result.response.text());
    }

    /**
     * Attempt to process any social media URL directly via Gemini.
     * Works for YouTube, and sometimes other platforms.
     * If this fails, caller should fall back to download approach.
     */
    async generateRecipeFromURL(url: string) {
        // Gemini Flash 1.5/2.0 does not support direct URL scraping for video.
        // We forces the controller to fall back to the "Download -> Upload -> Generate" flow.
        logger.warn(`Direct URL processing deprecated/unsupported for ${url}. Throwing error to trigger fallback.`);
        throw new Error("Direct URL processing not supported. Use fallback.");
    }

    /**
     * Generate a recipe from web page content.
     * Accepts pre-extracted data from WebRecipeScraper.
     */
    async generateRecipeFromWebpage(webData: {
        title?: string;
        description?: string;
        ingredients?: string[];
        instructions?: string[];
        rawText: string;
        author?: string;
        cookTime?: string;
        hasStructuredData: boolean;
    }, preferences?: RecipePreferences) {
        const model = genAI.getGenerativeModel({ model: AI_MODELS.RECIPE_ENGINE });

        // Build context from extracted data
        let context = '';

        if (webData.hasStructuredData) {
            context += 'STRUCTURED DATA EXTRACTED FROM PAGE:\n';
            if (webData.title) context += `Title: ${webData.title}\n`;
            if (webData.description) context += `Description: ${webData.description}\n`;
            if (webData.author) context += `Author: ${webData.author}\n`;
            if (webData.cookTime) context += `Cook Time: ${webData.cookTime}\n`;
            if (webData.ingredients && webData.ingredients.length > 0) {
                context += `Ingredients:\n${webData.ingredients.map(i => `- ${i}`).join('\n')}\n`;
            }
            if (webData.instructions && webData.instructions.length > 0) {
                context += `Instructions:\n${webData.instructions.map((s, i) => `${i + 1}. ${s}`).join('\n')}\n`;
            }
            context += '\n';
        }

        context += 'RAW PAGE TEXT:\n' + webData.rawText;

        const FULL_PROMPT = `${getWebRecipePrompt(preferences)}\n\nWEB PAGE CONTENT:\n${context}`;

        logger.info(`Generating recipe from web page content (unitSystem: ${preferences?.unitSystem || 'imperial'})`);
        const result = await withRetry(() => model.generateContent(FULL_PROMPT), {}, 'Gemini: generateRecipeFromWebpage');
        return this.parseRecipeResponse(result.response.text());
    }

    async remixRecipe(originalRecipe: any, userPrompt: string) {
        const model = genAI.getGenerativeModel({ model: AI_MODELS.RECIPE_ENGINE })

        const REMIX_PROMPT = `
        ${REMIX_SYSTEM_PROMPT}

        ORIGINAL RECIPE:
        ${JSON.stringify(originalRecipe)}

        USER REQUEST:
        "${userPrompt}"
    `

        const result = await withRetry(() => model.generateContent(REMIX_PROMPT), {}, 'Gemini: remixRecipe');
        return this.parseRecipeResponse(result.response.text());
    }

    async remixConsult(originalRecipe: any, chatHistory: any[], userPrompt: string) {
        const model = genAI.getGenerativeModel({ model: AI_MODELS.RECIPE_ENGINE });

        const historyContext = chatHistory.map(msg =>
            `${msg.role === 'user' ? 'User' : 'Chef'}: ${msg.content}`
        ).join('\n');

        const CONSULT_PROMPT = `
        ${REMIX_CONSULT_SYSTEM_PROMPT}

        ORIGINAL RECIPE:
        ${JSON.stringify(originalRecipe)}

        CONVERSATION HISTORY:
        ${historyContext}

        USER REQUEST:
        "${userPrompt}"
        `;

        const result = await withRetry(() => model.generateContent(CONSULT_PROMPT), {}, 'Gemini: remixConsult');
        const data = this.parseJsonFromResponse(result.response.text());
        if (!data) {
            throw new Error("No valid JSON object found in Gemini remix consult response");
        }
        return data;
    }

    async generateRecipeFromPrompt(userPrompt: string, preferences?: RecipePreferences) {
        try {
            logger.debug(`Generating recipe with ${AI_MODELS.RECIPE_ENGINE} (unitSystem: ${preferences?.unitSystem || 'imperial'})...`);
            const model = genAI.getGenerativeModel({ model: AI_MODELS.RECIPE_ENGINE });

            const FULL_PROMPT = `
            ${getPromptToRecipePrompt(preferences)}

            USER DESCRIPTION:
            "${userPrompt}"
            `;

            const result = await withRetry(() => model.generateContent(FULL_PROMPT), {}, 'Gemini: generateRecipeFromPrompt');
            const responseText = result.response.text();
            logger.debug(`${AI_MODELS.RECIPE_ENGINE} response received`);
            return this.parseRecipeResponse(responseText);
        } catch (error: any) {
            logger.error(`${AI_MODELS.RECIPE_ENGINE} Error (generateRecipeFromPrompt)`, error);
            throw error;
        }
    }

    private parseRecipeResponse(responseText: string) {
        const data = this.parseJsonFromResponse(responseText);
        if (!data) {
            throw new Error("No valid JSON object found in Gemini response");
        }
        return data;
    }
    async generateEmbedding(text: string) {
        const model = genAI.getGenerativeModel({ model: AI_MODELS.EMBEDDING });
        const result = await withRetry(() => model.embedContent(text), {}, 'Gemini: generateEmbedding');
        return result.embedding.values;
    }

    /**
     * Generate a food image for a recipe using Gemini's image generation (Nano Banana).
     * Returns base64 encoded image data.
     */
    async generateFoodImage(recipeTitle: string, description?: string): Promise<string | null> {
        try {
            // Use Gemini for image generation (Nano Banana)
            const model = genAI.getGenerativeModel({
                model: AI_MODELS.IMAGE_GEN
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
            const result = model.generateContent(imagePrompt);

            // Extract image from response
            const response = (await result).response;
            const parts = response.candidates?.[0]?.content?.parts || [];

            for (const part of parts) {
                // Check for inline image data
                const partAny = part as any;
                if (partAny.inlineData?.data) {
                    logger.info("Generated food image successfully");
                    return partAny.inlineData.data; // base64 encoded image
                }
            }

            logger.warn("No image data in response - model may not support image generation");
            return null;
        } catch (error: any) {
            logger.error(`Error generating food image: ${error.message}`);
            return null;
        }
    }
}
