
import express from 'express';
import { supabase } from '../db/supabase';
import { VideoDownloader } from '../services/video_downloader';
import { GeminiService } from '../services/gemini';
import fs from 'fs';

const router = express.Router();
const downloader = new VideoDownloader();
const gemini = new GeminiService();

// Helper to detect social media URLs that Gemini might process directly
function isDirectProcessableUrl(url: string): boolean {
    return url.includes('youtube.com') ||
        url.includes('youtu.be') ||
        url.includes('instagram.com') ||
        url.includes('tiktok.com');
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

        // Try processing directly with Gemini first (works for YouTube, might work for others)
        if (isDirectProcessableUrl(url)) {
            console.log("Social media URL detected - trying direct Gemini processing");
            try {
                recipeData = await gemini.generateRecipeFromURL(url);
                console.log("Direct processing succeeded!");
            } catch (directError: any) {
                console.log("Direct processing failed, will try download approach:", directError.message);
                // If direct processing fails, try downloading (requires RapidAPI subscription)
                const videoPath = await downloader.downloadVideo(url);
                console.log("Video downloaded:", videoPath);

                const uploadFile = await gemini.uploadVideo(videoPath);
                console.log("Uploaded to Gemini:", uploadFile.uri);

                await gemini.waitForProcessing(uploadFile.name);
                recipeData = await gemini.generateRecipe(uploadFile.uri);

                // Cleanup
                if (fs.existsSync(videoPath)) {
                    fs.unlinkSync(videoPath);
                }
            }
        } else {
            // For other URLs, download first
            console.log("Unknown video source - downloading first");
            const videoPath = await downloader.downloadVideo(url);
            console.log("Video downloaded:", videoPath);

            const uploadFile = await gemini.uploadVideo(videoPath);
            await gemini.waitForProcessing(uploadFile.name);
            recipeData = await gemini.generateRecipe(uploadFile.uri);

            if (fs.existsSync(videoPath)) {
                fs.unlinkSync(videoPath);
            }
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

        res.json({ success: true, recipe: data });

    } catch (error: any) {
        console.error("Error processing recipe:", error);
        res.status(500).json({ error: error.message || "Internal Server Error" });
    }
});

router.post('/register-device', async (req, res) => {
    try {
        const { userId, deviceToken, platform } = req.body;

        if (!userId || !deviceToken || !platform) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        // Upsert device token
        const { data, error } = await supabase
            .from('user_devices')
            .upsert({
                user_id: userId,
                device_token: deviceToken,
                platform: platform,
                updated_at: new Date().toISOString()
            }, { onConflict: 'user_id, device_token' })
            .select()
            .single();

        if (error) throw error;

        res.json({ success: true, device: data });
    } catch (error: any) {
        console.error("Error registering device:", error);
        res.status(500).json({ error: error.message });
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
