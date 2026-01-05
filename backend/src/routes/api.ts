
import express from 'express';
import { supabase } from '../db/supabase';
import { VideoDownloader } from '../services/video_downloader';
import { GeminiService } from '../services/gemini';
import fs from 'fs';

const router = express.Router();
const downloader = new VideoDownloader();
const gemini = new GeminiService();

// Helper to detect YouTube URLs
function isYouTubeUrl(url: string): boolean {
    return url.includes('youtube.com') || url.includes('youtu.be');
}

router.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'My Social Cookbook Backend' });
});

router.post('/process-recipe', async (req, res) => {
    try {
        const { url, userId } = req.body;

        if (!url || !userId) {
            return res.status(400).json({ error: 'Missing url or userId' });
        }

        console.log(`Processing recipe for user ${userId} from ${url}`);

        let recipeData;
        let videoPath: string | null = null;

        // For YouTube: process directly with Gemini (no download needed!)
        if (isYouTubeUrl(url)) {
            console.log("YouTube detected - processing directly with Gemini");
            recipeData = await gemini.generateRecipeFromYouTube(url);
        } else {
            // For TikTok/Instagram: download first, then upload to Gemini
            console.log("Non-YouTube video - downloading first");
            videoPath = await downloader.downloadVideo(url);
            console.log("Video downloaded:", videoPath);

            // Upload to Gemini
            const uploadFile = await gemini.uploadVideo(videoPath);
            console.log("Uploaded to Gemini:", uploadFile.uri);

            await gemini.waitForProcessing(uploadFile.name);

            // Extract Recipe
            recipeData = await gemini.generateRecipe(uploadFile.uri);
        }

        console.log("Recipe extracted:", recipeData.title);

        // Generate Embedding for Search
        const embeddingText = `${recipeData.title} ${recipeData.description} ${recipeData.ingredients.map((i: any) => i.name).join(' ')}`;
        const embedding = await gemini.generateEmbedding(embeddingText);

        // Save to Supabase
        const { data, error } = await supabase
            .from('recipes')
            .insert({
                user_id: userId,
                title: recipeData.title,
                description: recipeData.description,
                video_url: url,
                ingredients: recipeData.ingredients,
                instructions: recipeData.instructions,
                embedding: embedding
            })
            .select()
            .single();

        if (error) {
            console.error("Supabase Insert Error:", error);
            throw error;
        }

        // Cleanup local file (if we downloaded one)
        if (videoPath && fs.existsSync(videoPath)) {
            fs.unlinkSync(videoPath);
        }

        res.json({ success: true, recipe: data });

    } catch (error: any) {
        console.error("Error processing recipe:", error);
        res.status(500).json({ error: error.message || "Internal Server Error" });
    }
});

// For feed (utility endpoint)
router.get('/recipes', async (req, res) => {
    const { data, error } = await supabase
        .from('recipes')
        .select('*, profiles(*)')
        .order('created_at', { ascending: false });

    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
});

export default router;
