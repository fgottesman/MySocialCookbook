
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

export class GeminiService {

    async uploadVideo(path: string, mimeType: string = "video/mp4") {
        const uploadResult = await fileManager.uploadFile(path, {
            mimeType,
            displayName: "Social Recipe Video",
        });

        console.log(`Uploaded file ${uploadResult.file.displayName} as: ${uploadResult.file.uri}`);
        return uploadResult.file;
    }

    async waitForProcessing(fileName: string) {
        let file = await fileManager.getFile(fileName);
        while (file.state === "PROCESSING") {
            process.stdout.write(".");
            await new Promise((resolve) => setTimeout(resolve, 2000));
            file = await fileManager.getFile(fileName);
        }
        console.log(`File state: ${file.state}`);
        return file;
    }

    async generateRecipe(fileUri: string) {
        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

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

        // Use gemini-2.5-flash which has better YouTube support
        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

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
