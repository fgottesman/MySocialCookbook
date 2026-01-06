
import express from 'express';
import { supabase } from '../db/supabase';
import { VideoDownloader } from '../services/video_downloader';
import { GeminiService } from '../services/gemini';
import { apnsService } from '../services/apns';
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

// Helper to send push notification to user
async function notifyUser(userId: string, title: string, body: string, recipeId?: string) {
    try {
        // Get user's device token
        const { data: devices } = await supabase
            .from('user_devices')
            .select('device_token')
            .eq('user_id', userId)
            .eq('platform', 'ios');

        if (devices && devices.length > 0) {
            for (const device of devices) {
                await apnsService.sendNotification(device.device_token, {
                    title,
                    body,
                    recipeId
                });
            }
            console.log(`Push notification sent to ${devices.length} device(s)`);
        } else {
            console.log('No devices registered for user', userId);
        }
    } catch (error) {
        console.error('Error sending push notification:', error);
    }
}

router.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'My Social Cookbook Backend' });
});

router.post('/process-recipe', async (req, res) => {
    const { url, userId } = req.body;

    // Send immediate response for fire-and-forget from Share Extension
    res.json({ success: true, message: 'Processing started' });

    try {
        if (!url || !userId) {
            console.error('Missing url or userId');
            return;
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
                const { filePath: videoPath, thumbnailUrl } = await downloader.downloadVideo(url);
                console.log("Video downloaded:", videoPath);

                const uploadFile = await gemini.uploadVideo(videoPath);
                console.log("Uploaded to Gemini:", uploadFile.uri);

                await gemini.waitForProcessing(uploadFile.name);
                recipeData = await gemini.generateRecipe(uploadFile.uri);

                // Add thumbnail to recipeData so we can use it later
                recipeData.thumbnailUrl = thumbnailUrl;

                // Cleanup
                if (fs.existsSync(videoPath)) {
                    fs.unlinkSync(videoPath);
                }
            }
        } else {
            // For other URLs, download first
            console.log("Unknown video source - downloading first");
            const { filePath: videoPath, thumbnailUrl } = await downloader.downloadVideo(url);
            console.log("Video downloaded:", videoPath);

            const uploadFile = await gemini.uploadVideo(videoPath);
            await gemini.waitForProcessing(uploadFile.name);
            recipeData = await gemini.generateRecipe(uploadFile.uri);

            // Add thumbnail to recipeData
            recipeData.thumbnailUrl = thumbnailUrl;

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
                embedding: embedding,
                thumbnail_url: recipeData.thumbnailUrl || null
            })
            .select()
            .single();

        if (error) {
            console.error("Supabase Insert Error:", error);
            await notifyUser(userId, 'Recipe Failed 😕', 'We couldn\'t process that video. Try another one!');
            return;
        }

        // SUCCESS - Send push notification!
        await notifyUser(
            userId,
            '🍳 Recipe Ready!',
            `"${recipeData.title}" has been extracted and is ready to cook!`,
            data.id
        );

        console.log("Recipe saved and notification sent:", data.id);

    } catch (error: any) {
        console.error("Error processing recipe:", error);
        if (userId) {
            await notifyUser(userId, 'Recipe Failed 😕', 'Something went wrong. Please try again.');
        }
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

router.post('/remix-recipe', async (req, res) => {
    try {
        const { originalRecipe, userPrompt } = req.body;

        if (!originalRecipe || !userPrompt) {
            return res.status(400).json({ error: 'Missing originalRecipe or userPrompt' });
        }

        console.log(`Remixing recipe with prompt: "${userPrompt}"`);

        const remixedRecipe = await gemini.remixRecipe(originalRecipe, userPrompt);

        console.log("Remix complete:", remixedRecipe.title);

        res.json({ success: true, recipe: remixedRecipe });

    } catch (error: any) {
        console.error("Error remixing recipe:", error);
        res.status(500).json({ error: error.message });
    }
});

router.post('/chat-companion', async (req, res) => {
    try {
        const { recipe, currentStepIndex, chatHistory, userMessage } = req.body;

        if (!recipe || !userMessage) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        console.log(`Voice Companion Chat: "${userMessage}" (Step ${currentStepIndex})`);

        const reply = await gemini.chatCompanion(
            recipe,
            currentStepIndex || 0,
            chatHistory || [],
            userMessage
        );

        console.log("Companion Reply:", reply);

        res.json({ success: true, reply: reply });

    } catch (error: any) {
        console.error("Error in Voice Companion:", error);
        res.status(500).json({ error: error.message });
    }
});

router.post('/transcribe-audio', async (req, res) => {
    try {
        const { audioBase64, mimeType } = req.body;

        if (!audioBase64) {
            return res.status(400).json({ error: 'Missing audioBase64' });
        }

        console.log(`Transcribing audio (${mimeType || 'audio/webm'}, ${audioBase64.length} chars)`);

        const transcript = await gemini.transcribeAudio(audioBase64, mimeType || 'audio/webm');

        console.log("Transcript:", transcript);

        res.json({ success: true, transcript: transcript });

    } catch (error: any) {
        console.error("Error transcribing audio:", error);
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
