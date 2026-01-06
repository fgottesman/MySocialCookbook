
import { GoogleGenerativeAI } from "@google/generative-ai";
import dotenv from 'dotenv';

dotenv.config();

const apiKey = process.env.GEMINI_API_KEY;

if (!apiKey) {
    console.error("No API key found in env");
    process.exit(1);
}

const genAI = new GoogleGenerativeAI(apiKey);

async function listModels() {
    try {
        console.log("Fetching available models...");
        // Note: The SDK might not expose listModels directly on the main class in all versions,
        // but often it's available or we can check the error details more closely.
        // Actually, for the JS SDK, we iterate through models via the API if supported,
        // but the SDK documentation often points to creating a model.
        // Let's try to infer or finding a list method.
        // If the SDK doesn't have a simple list method exposed in this version, we might have to rely on known model names.
        // However, standard Google Cloud/Vertex AI often has list_models.
        // Let's try a direct REST call if the SDK doesn't support it easily, 
        // but `GoogleGenerativeAI` usually has a way. 
        // Actually, looking at the error `at _makeRequestInternal`, it suggests the standard SDK structure.

        // Let's try a direct REST call to https://generativelanguage.googleapis.com/v1beta/models?key=API_KEY

        const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`);
        const data = await response.json();

        if (data.models) {
            console.log("\nAvailable Models:");
            data.models.forEach((m: any) => {
                console.log(`- ${m.name} (${m.displayName}) - Supported generation methods: ${m.supportedGenerationMethods}`);
            });
        } else {
            console.log("No models found or error structure:", data);
        }
    } catch (error) {
        console.error("Error listing models:", error);
    }
}

listModels();
