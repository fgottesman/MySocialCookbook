import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { GeminiService } from '../services/gemini';
import { ttsService } from '../services/tts';
import crypto from 'crypto';
import logger from '../utils/logger';

const gemini = new GeminiService();

export class AiController {
    static async generateFromPrompt(req: AuthRequest, res: Response) {
        try {
            const { prompt } = req.body;
            const userId = req.user.id;
            logger.info(`AI: Generating recipe from prompt for user ${userId}`);
            const recipeData = await gemini.generateRecipeFromPrompt(prompt);

            const embeddingText = `${recipeData.title} ${recipeData.description} ${recipeData.ingredients.map((i: any) => i.name).join(' ')}`;
            const embedding = await gemini.generateEmbedding(embeddingText);

            // Handle Step 0 Audio
            let step0AudioUrl = null;
            if (recipeData.step0Summary) {
                const audioBase64 = await ttsService.synthesize(recipeData.step0Summary);
                const audioName = `audio_${crypto.randomUUID()}.mp3`;
                const audioBuffer = Buffer.from(audioBase64, 'base64');
                const { error } = await req.supabase.storage.from('recipe-thumbnails').upload(audioName, audioBuffer, { contentType: 'audio/mpeg', upsert: true });
                if (!error) {
                    step0AudioUrl = req.supabase.storage.from('recipe-thumbnails').getPublicUrl(audioName).data.publicUrl;
                }
            }

            // AI Image Generation
            let thumbnailUrl = null;
            try {
                logger.info("AI: Generating food image");
                const imageBase64 = await gemini.generateFoodImage(recipeData.title, recipeData.description);
                if (imageBase64) {
                    const imageName = `ai_recipe_${crypto.randomUUID()}.png`;
                    const imageBuffer = Buffer.from(imageBase64, 'base64');
                    const { error: uploadError } = await req.supabase.storage.from('recipe-thumbnails').upload(imageName, imageBuffer, { contentType: 'image/png', upsert: true });
                    if (!uploadError) {
                        thumbnailUrl = req.supabase.storage.from('recipe-thumbnails').getPublicUrl(imageName).data.publicUrl;
                    }
                }
            } catch (e: any) {
                logger.error(`AI: Image Generation Failed: ${e.message}`);
            }

            const { data, error } = await req.supabase.from('recipes').insert({
                user_id: userId,
                title: recipeData.title,
                description: recipeData.description,
                ingredients: recipeData.ingredients,
                instructions: recipeData.instructions,
                embedding: embedding,
                thumbnail_url: thumbnailUrl,
                step0_summary: recipeData.step0Summary,
                step0_audio_url: step0AudioUrl,
                difficulty: recipeData.difficulty,
                cooking_time: recipeData.cookingTime
            }).select().single();

            if (error) throw error;
            res.json({ success: true, recipeId: data.id, recipe: data });
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    static async remixRecipe(req: AuthRequest, res: Response) {
        try {
            const { originalRecipe, userPrompt } = req.body;
            const userId = req.user.id;
            const remixedData = await gemini.remixRecipe(originalRecipe, userPrompt);
            res.json(remixedData);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    static async remixChat(req: AuthRequest, res: Response) {
        try {
            const { originalRecipe, chatHistory, userPrompt } = req.body;
            const response = await gemini.remixConsult(originalRecipe, chatHistory, userPrompt);
            res.json(response);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    static async chatCompanion(req: AuthRequest, res: Response) {
        try {
            const { recipe, currentStepIndex, chatHistory, userMessage } = req.body;
            const response = await gemini.chatCompanion(recipe, currentStepIndex, chatHistory, userMessage);
            res.json(response);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    static async prepareStep(req: AuthRequest, res: Response) {
        try {
            const { recipe, stepIndex, stepLabel } = req.body;
            const response = await gemini.prepareStep(recipe, stepIndex, stepLabel);
            res.json(response);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    static async transcribeAudio(req: AuthRequest, res: Response) {
        try {
            const { audioBase64, mimeType } = req.body;
            const text = await gemini.transcribeAudio(audioBase64, mimeType);
            res.json({ text });
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    static async synthesize(req: AuthRequest, res: Response) {
        try {
            const { text } = req.body;
            const audioBase64 = await ttsService.synthesize(text);
            res.json({ audioBase64 });
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }
}
