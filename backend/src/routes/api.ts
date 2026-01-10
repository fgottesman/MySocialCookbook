
import express from 'express';
import { supabase } from '../db/supabase';
import { VideoDownloader } from '../services/video_downloader';
import { GeminiService } from '../services/gemini';
import { ttsService } from '../services/tts';
import { apnsService } from '../services/apns';
import { authenticate, AuthRequest } from '../middleware/auth';
import { apiLimiter, aiLimiter } from '../middleware/rateLimit';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

const router = express.Router();
const downloader = new VideoDownloader();
const gemini = new GeminiService();

// Apply general rate limit to all routes in this router
router.use(apiLimiter);

// Helper to detect social media URLs
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
    res.json({ status: 'ok', service: 'ClipCook Backend' });
});

router.post('/process-recipe', authenticate, aiLimiter, async (req: AuthRequest, res) => {
    const { url } = req.body;
    const userId = req.user.id;

    // Send immediate response for fire-and-forget from Share Extension
    res.json({ success: true, message: 'Processing started' });

    try {
        if (!url || !userId) {
            console.error('Missing url or userId');
            return;
        }

        console.log(`Processing recipe for user ${userId} from ${url}`);

        let recipeData;
        let finalDescription: string | undefined;

        // Try processing directly with Gemini first (works for YouTube, might work for others)
        if (isDirectProcessableUrl(url)) {
            console.log("Social media URL detected - trying direct Gemini processing");
            try {
                recipeData = await gemini.generateRecipeFromURL(url);
                console.log("Direct processing succeeded!");
            } catch (directError: any) {
                console.log("Direct processing failed, will try download approach:", directError.message);

                // FALLBACK: Download and process
                const { filePath: mediaPath, thumbnailUrl, description, mimeType } = await downloader.downloadMedia(url);
                finalDescription = description;

                console.log(`${mimeType} downloaded:`, mediaPath);

                const uploadFile = await gemini.uploadMedia(mediaPath, mimeType);
                await gemini.waitForProcessing(uploadFile.name);
                recipeData = await gemini.generateRecipe(uploadFile.uri, mimeType, description);

                // Add thumbnail to recipeData
                recipeData.thumbnailUrl = thumbnailUrl;

                // Cleanup
                if (fs.existsSync(mediaPath)) {
                    fs.unlinkSync(mediaPath);
                }
            }
        } else {
            // For other URLs, download first
            console.log("Unknown video source - downloading first");
            const { filePath: mediaPath, thumbnailUrl, description, mimeType } = await downloader.downloadMedia(url);
            finalDescription = description;

            const uploadFile = await gemini.uploadMedia(mediaPath, mimeType);
            await gemini.waitForProcessing(uploadFile.name);
            recipeData = await gemini.generateRecipe(uploadFile.uri, mimeType, description);

            recipeData.thumbnailUrl = thumbnailUrl;

            if (fs.existsSync(mediaPath)) {
                fs.unlinkSync(mediaPath);
            }
        }

        // --- Handle Thumbnail Persistence ---
        if (recipeData.thumbnailUrl) {
            try {
                console.log("Processing thumbnail for persistence...");
                const downloadDir = path.join(__dirname, '../../downloads');
                if (!fs.existsSync(downloadDir)) {
                    fs.mkdirSync(downloadDir, { recursive: true });
                }

                const thumbName = `thumb_${crypto.randomUUID()}.jpg`;
                const thumbPath = path.join(downloadDir, thumbName);

                await downloader.downloadThumbnail(recipeData.thumbnailUrl, thumbPath);

                const { data: uploadData, error: uploadError } = await req.supabase.storage
                    .from('recipe-thumbnails')
                    .upload(thumbName, fs.readFileSync(thumbPath), {
                        contentType: 'image/jpeg',
                        upsert: true
                    });

                if (uploadError) {
                    console.error("Supabase Storage Upload Error:", uploadError);
                } else {
                    const { data: publicUrlData } = req.supabase.storage
                        .from('recipe-thumbnails')
                        .getPublicUrl(thumbName);

                    if (publicUrlData && publicUrlData.publicUrl) {
                        console.log("Thumbnail uploaded permanently:", publicUrlData.publicUrl);
                        recipeData.thumbnailUrl = publicUrlData.publicUrl;
                    }
                }

                if (fs.existsSync(thumbPath)) {
                    fs.unlinkSync(thumbPath);
                }
            } catch (thumbError) {
                console.error("Error processing permanent thumbnail:", thumbError);
            }
        }

        console.log("Recipe extracted:", recipeData.title);

        // Generate Embedding for Search
        const embeddingText = `${recipeData.title} ${recipeData.description} ${finalDescription || ''} ${recipeData.ingredients.map((i: { name: string }) => i.name).join(' ')}`;
        const embedding = await gemini.generateEmbedding(embeddingText);

        // --- Handle Step 0 Audio ---
        let step0AudioUrl: string | null = null;
        if (recipeData.step0Summary) {
            try {
                console.log("Synthesizing Step 0 Audio...");
                const audioBase64 = await ttsService.synthesize(recipeData.step0Summary);
                const audioName = `audio_${crypto.randomUUID()}.mp3`;
                const audioBuffer = Buffer.from(audioBase64, 'base64');

                // Upload to Supabase (using recipe-thumbnails bucket for now, or ensure recipe-audio exists)
                // We'll use 'recipe-thumbnails' since we know it works, but ideally separate bucket
                const { error: uploadError } = await req.supabase.storage
                    .from('recipe-thumbnails')
                    .upload(audioName, audioBuffer, {
                        contentType: 'audio/mpeg',
                        upsert: true
                    });

                if (uploadError) {
                    console.error("Step 0 Audio Upload Error:", uploadError);
                } else {
                    const { data: publicUrlData } = req.supabase.storage
                        .from('recipe-thumbnails')
                        .getPublicUrl(audioName);

                    if (publicUrlData?.publicUrl) {
                        step0AudioUrl = publicUrlData.publicUrl;
                        console.log("Step 0 Audio ready:", step0AudioUrl);
                    }
                }
            } catch (audioError) {
                console.error("Error creating Step 0 Audio:", audioError);
            }
        }

        // Save to Supabase
        const { data, error } = await req.supabase
            .from('recipes')
            .insert({
                user_id: userId,
                title: recipeData.title,
                description: recipeData.description,
                video_url: url,
                ingredients: recipeData.ingredients,
                instructions: recipeData.instructions,
                embedding: embedding,
                thumbnail_url: recipeData.thumbnailUrl || null,
                step0_summary: recipeData.step0Summary || null,
                step0_audio_url: step0AudioUrl || null,
                difficulty: recipeData.difficulty || null,
                cooking_time: recipeData.cookingTime || null
            })
            .select()
            .single();

        if (error) {
            console.error("Supabase Insert Error:", error);
            await notifyUser(userId, 'Recipe Failed 😕', 'We couldn\'t save the recipe results. Please try again.');
            return;
        }

        // SUCCESS - notify user immediately
        await notifyUser(
            userId,
            '🍳 Recipe Ready!',
            `"${recipeData.title}" has been extracted and is ready to cook!`,
            data.id
        );

        console.log("Recipe saved and notification sent:", data.id);

        // Pre-compute step preparations in background (don't block user notification)
        try {
            const stepPreparations = await gemini.prepareAllSteps({
                title: recipeData.title,
                ingredients: recipeData.ingredients,
                instructions: recipeData.instructions
            });

            await supabase
                .from('recipes')
                .update({ step_preparations: stepPreparations })
                .eq('id', data.id);

            console.log(`Step preparations saved for recipe ${data.id}`);
        } catch (prepError) {
            console.error("Error pre-computing step preparations (non-blocking):", prepError);
        }

    } catch (error: any) {
        console.error("Error processing recipe:", error);

        let message = 'Something went wrong. Please try again.';
        let title = 'Recipe Failed 😕';

        if (error.message?.includes('RapidAPI subscription')) {
            message = 'Our social connection is down. Please check back later!';
        } else if (error.message?.includes('Internal Server Error')) {
            message = 'Our AI chef got a bit confused. Try a different video!';
        } else if (error.message?.includes('safety')) {
            message = 'We couldn\'t process this due to content safety rules.';
        }

        if (userId) {
            await notifyUser(userId, title, message);
        }
    }
});

router.post('/generate-recipe-from-prompt', authenticate, aiLimiter, async (req: AuthRequest, res) => {
    try {
        const { prompt } = req.body;
        const userId = req.user.id;

        if (!prompt || !userId) {
            return res.status(400).json({ error: 'Missing prompt or userId' });
        }

        console.log(`Generating recipe for user ${userId} from prompt: "${prompt}"`);

        const recipeData = await gemini.generateRecipeFromPrompt(prompt);

        console.log("Recipe generated:", recipeData.title);

        // Generate Embedding for Search
        const embeddingText = `${recipeData.title} ${recipeData.description} ${recipeData.ingredients.map((i: { name: string }) => i.name).join(' ')}`;
        const embedding = await gemini.generateEmbedding(embeddingText);

        // --- Handle Step 0 Audio ---
        let step0AudioUrl: string | null = null;
        if (recipeData.step0Summary) {
            try {
                console.log("Synthesizing Step 0 Audio...");
                const audioBase64 = await ttsService.synthesize(recipeData.step0Summary);
                const audioName = `audio_${crypto.randomUUID()}.mp3`;
                const audioBuffer = Buffer.from(audioBase64, 'base64');

                const { error: uploadError } = await req.supabase.storage
                    .from('recipe-thumbnails')
                    .upload(audioName, audioBuffer, {
                        contentType: 'audio/mpeg',
                        upsert: true
                    });

                if (uploadError) {
                    console.error("Step 0 Audio Upload Error:", uploadError);
                } else {
                    const { data: publicUrlData } = req.supabase.storage
                        .from('recipe-thumbnails')
                        .getPublicUrl(audioName);

                    if (publicUrlData?.publicUrl) {
                        step0AudioUrl = publicUrlData.publicUrl;
                        console.log("Step 0 Audio ready:", step0AudioUrl);
                    }
                }
            } catch (audioError) {
                console.error("Error creating Step 0 Audio:", audioError);
            }
        }

        // Generate AI food image for thumbnail
        let thumbnailUrl: string | null = null;
        try {
            console.log("Generating AI food image...");
            const imageBase64 = await gemini.generateFoodImage(recipeData.title, recipeData.description);

            if (imageBase64) {
                // Upload to Supabase storage
                const imageName = `ai_recipe_${crypto.randomUUID()}.png`;
                const imageBuffer = Buffer.from(imageBase64, 'base64');

                const { data: uploadData, error: uploadError } = await supabase.storage
                    .from('recipe-thumbnails')
                    .upload(imageName, imageBuffer, {
                        contentType: 'image/png',
                        upsert: true
                    });

                if (uploadError) {
                    console.error("Image upload error:", uploadError);
                } else {
                    const { data: publicUrlData } = supabase.storage
                        .from('recipe-thumbnails')
                        .getPublicUrl(imageName);

                    if (publicUrlData?.publicUrl) {
                        thumbnailUrl = publicUrlData.publicUrl;
                        console.log("AI thumbnail uploaded:", thumbnailUrl);
                    }
                }
            }
        } catch (imageError: any) {
            console.error("Error generating/uploading AI image:", imageError.message);
            // Continue without thumbnail - non-blocking
        }

        // Save to Supabase
        const { data, error } = await req.supabase
            .from('recipes')
            .insert({
                user_id: userId,
                title: recipeData.title,
                description: recipeData.description,
                video_url: null,
                thumbnail_url: thumbnailUrl,
                ingredients: recipeData.ingredients,
                instructions: recipeData.instructions,
                chefs_note: recipeData.chefsNote || null,
                source_prompt: prompt, // Store the AI prompt for attribution
                embedding: embedding,
                step0_summary: recipeData.step0Summary || null,
                step0_audio_url: step0AudioUrl || null,
                difficulty: recipeData.difficulty || null,
                cooking_time: recipeData.cookingTime || null
            })
            .select()
            .single();

        if (error) {
            console.error("Supabase Insert Error:", error);
            return res.status(500).json({ error: 'Failed to save recipe' });
        }

        // Pre-compute step preparations (non-blocking for response, but we await)
        try {
            const stepPreparations = await gemini.prepareAllSteps({
                title: recipeData.title,
                ingredients: recipeData.ingredients,
                instructions: recipeData.instructions
            });

            await supabase
                .from('recipes')
                .update({ step_preparations: stepPreparations })
                .eq('id', data.id);

            // Include in response so iOS has it immediately
            data.step_preparations = stepPreparations;
            console.log(`Step preparations saved for AI recipe ${data.id}`);
        } catch (prepError) {
            console.error("Error pre-computing step preparations:", prepError);
        }

        res.json({ success: true, recipe: data });

    } catch (error: any) {
        console.error("Error generating recipe from prompt:", error);
        res.status(500).json({ error: error.message });
    }
});

router.post('/register-device', authenticate, async (req: AuthRequest, res) => {
    try {
        const { deviceToken, platform } = req.body;
        const userId = req.user.id;

        if (!userId || !deviceToken || !platform) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        // Upsert device token
        const { data, error } = await req.supabase
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

router.post('/remix-recipe', authenticate, aiLimiter, async (req: AuthRequest, res) => {
    try {
        const { originalRecipe, userPrompt } = req.body;
        const userId = req.user.id;

        if (!originalRecipe || !userPrompt) {
            return res.status(400).json({ error: 'Missing originalRecipe or userPrompt' });
        }

        console.log(`[Remix] User ${userId} remixing recipe: "${userPrompt}"`);

        const remixedRecipe = await gemini.remixRecipe(originalRecipe, userPrompt);

        console.log("Remix complete:", remixedRecipe.title);

        // --- Handle Step 0 Audio for Remix ---
        if (remixedRecipe.step0Summary) {
            try {
                console.log("Synthesizing Remix Step 0 Audio...");
                const audioBase64 = await ttsService.synthesize(remixedRecipe.step0Summary);
                const audioName = `audio_remix_${crypto.randomUUID()}.mp3`;
                const audioBuffer = Buffer.from(audioBase64, 'base64');

                const { error: uploadError } = await req.supabase.storage
                    .from('recipe-thumbnails')
                    .upload(audioName, audioBuffer, {
                        contentType: 'audio/mpeg',
                        upsert: true
                    });

                if (!uploadError) {
                    const { data: publicUrlData } = req.supabase.storage
                        .from('recipe-thumbnails')
                        .getPublicUrl(audioName);

                    if (publicUrlData?.publicUrl) {
                        remixedRecipe.step0AudioUrl = publicUrlData.publicUrl;
                    }
                }
            } catch (audioError) {
                console.error("Error creating Remix Audio:", audioError);
            }
        }

        res.json({ success: true, recipe: remixedRecipe });

    } catch (error: any) {
        console.error("Error remixing recipe:", error);
        res.status(500).json({ error: error.message });
    }
});

router.post('/remix-chat', authenticate, aiLimiter, async (req: AuthRequest, res) => {
    try {
        const { originalRecipe, chatHistory, userPrompt } = req.body;

        if (!originalRecipe || !userPrompt) {
            return res.status(400).json({ error: 'Missing originalRecipe or userPrompt' });
        }

        console.log(`Remix Consultation for user ${req.user.id}: "${userPrompt}"`);

        const consultation = await gemini.remixConsult(originalRecipe, chatHistory || [], userPrompt);

        console.log("Consultation:", consultation.reply?.substring(0, 50) + "...");

        res.json({ success: true, consultation });

    } catch (error: any) {
        console.error("Error in remix consultation:", error);
        res.status(500).json({ error: error.message });
    }
});

router.post('/chat-companion', authenticate, aiLimiter, async (req: AuthRequest, res) => {
    try {
        const { recipe, currentStepIndex, chatHistory, userMessage } = req.body;

        if (!recipe || !userMessage) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        console.log(`Voice Companion Chat (User ${req.user.id}): "${userMessage}" (Step ${currentStepIndex})`);

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

// Prepare a step for cooking mode - analyzes step, breaks down, provides conversions
router.post('/prepare-step', authenticate, aiLimiter, async (req: AuthRequest, res) => {
    try {
        const { recipe, stepIndex, stepLabel } = req.body;

        if (!recipe || stepIndex === undefined) {
            return res.status(400).json({ error: 'Missing recipe or stepIndex' });
        }

        console.log(`Preparing step ${stepIndex} for recipe: ${recipe.title}`);

        const preparation = await gemini.prepareStep(recipe, stepIndex, stepLabel || String(stepIndex + 1));

        console.log("Step preparation complete:", preparation.introduction?.substring(0, 50) + "...");

        res.json({ success: true, preparation });

    } catch (error: any) {
        console.error("Error preparing step:", error);
        res.status(500).json({ error: error.message });
    }
});

// Get user preferences
router.get('/user-preferences/:userId', authenticate, async (req: AuthRequest, res) => {
    try {
        const { userId } = req.params;

        // Force user to only see their own preferences
        if (userId !== req.user.id) {
            return res.status(403).json({ error: 'Forbidden: You can only access your own preferences' });
        }

        const { data, error } = await req.supabase
            .from('user_preferences')
            .select('*')
            .eq('user_id', userId)
            .single();

        if (error && error.code !== 'PGRST116') { // PGRST116 = no rows returned
            throw error;
        }

        // Return defaults if no preferences exist
        const preferences = data || {
            user_id: userId,
            unit_system: 'imperial', // default
            prep_style: 'just_in_time', // or 'prep_first'
            created_at: new Date().toISOString()
        };

        res.json({ success: true, preferences });

    } catch (error: any) {
        console.error("Error fetching preferences:", error);
        res.status(500).json({ error: error.message });
    }
});

// Update user preferences
router.put('/user-preferences/:userId', authenticate, async (req: AuthRequest, res) => {
    try {
        const { userId } = req.params;

        // Force user to only update their own preferences
        if (userId !== req.user.id) {
            return res.status(403).json({ error: 'Forbidden: You can only update your own preferences' });
        }
        const updates = req.body;

        // Upsert preferences
        const { data, error } = await req.supabase
            .from('user_preferences')
            .upsert({
                user_id: userId,
                ...updates,
                updated_at: new Date().toISOString()
            }, { onConflict: 'user_id' })
            .select()
            .single();

        if (error) throw error;

        res.json({ success: true, preferences: data });

    } catch (error: any) {
        console.error("Error updating preferences:", error);
        res.status(500).json({ error: error.message });
    }
});

router.post('/transcribe-audio', authenticate, aiLimiter, async (req: AuthRequest, res) => {
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

// Toggle favorite status
router.patch('/recipes/:id/favorite', authenticate, async (req: AuthRequest, res) => {
    try {
        const { id } = req.params;
        const { isFavorite } = req.body;
        const userId = req.user.id;

        if (!userId) {
            return res.status(401).json({ error: 'Unauthorized - missing user ID' });
        }

        if (typeof isFavorite !== 'boolean') {
            return res.status(400).json({ error: 'isFavorite must be a boolean' });
        }

        const { data, error } = await req.supabase
            .from('recipes')
            .update({ is_favorite: isFavorite })
            .eq('id', id)
            .eq('user_id', userId)
            .select()
            .single();

        if (error) throw error;

        res.json({ success: true, recipe: data });
    } catch (error: any) {
        console.error("Error toggling favorite:", error);
        res.status(500).json({ error: error.message });
    }
});

// Delete recipe
router.delete('/recipes/:id', authenticate, async (req: AuthRequest, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;

        if (!userId) {
            return res.status(401).json({ error: 'Unauthorized - missing user ID' });
        }

        const { error } = await req.supabase
            .from('recipes')
            .delete()
            .eq('id', id)
            .eq('user_id', userId);

        if (error) throw error;

        res.json({ success: true });
    } catch (error: any) {
        console.error("Error deleting recipe:", error);
        res.status(500).json({ error: error.message });
    }
});

// For feed (utility endpoint)
router.get('/recipes', authenticate, async (req: AuthRequest, res) => {
    const { data, error } = await req.supabase
        .from('recipes')
        .select('*, profiles(*)')
        .order('created_at', { ascending: false });

    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
});

router.post('/synthesize', authenticate, async (req: AuthRequest, res) => {
    try {
        const { text } = req.body;

        if (!text) {
            return res.status(400).json({ error: 'Missing text' });
        }

        console.log(`Synthesizing text (${text.length} chars)`);

        const audioBase64 = await ttsService.synthesize(text);

        res.json({ success: true, audioBase64 });

    } catch (error: any) {
        console.error("Error synthesizing speech:", error);
        res.status(500).json({ error: error.message });
    }
});

// Get versions for a recipe
router.get('/recipes/:recipeId/versions', authenticate, async (req: AuthRequest, res) => {
    try {
        const { recipeId } = req.params;

        const { data, error } = await req.supabase
            .from('recipe_versions')
            .select('*')
            .eq('recipe_id', recipeId)
            .order('version_number', { ascending: false });

        if (error) throw error;

        res.json({ success: true, versions: data || [] });
    } catch (error: any) {
        console.error("Error fetching versions:", error);
        res.status(500).json({ error: error.message });
    }
});

// Save a new version
router.post('/recipes/:recipeId/versions', authenticate, async (req: AuthRequest, res) => {
    try {
        const { recipeId } = req.params;
        const { title, description, ingredients, instructions, chefsNote, changedIngredients, step0Summary, step0AudioUrl, difficulty, cookingTime } = req.body;

        // 1. Get current max version
        const { data: versions, error: vError } = await req.supabase
            .from('recipe_versions')
            .select('version_number')
            .eq('recipe_id', recipeId)
            .order('version_number', { ascending: false })
            .limit(1);

        if (vError) throw vError;
        const nextVersion = (versions && versions.length > 0) ? (versions[0].version_number + 1) : 1;

        // 2. Insert new version
        const { data: vData, error: insertError } = await req.supabase
            .from('recipe_versions')
            .insert({
                recipe_id: recipeId,
                version_number: nextVersion,
                title,
                description,
                ingredients,
                instructions,
                chefs_note: chefsNote,
                changed_ingredients: JSON.stringify(changedIngredients), // Store as string if JSONB not using types correctly
                step0_summary: step0Summary,
                step0_audio_url: step0AudioUrl,
                difficulty,
                cooking_time: cookingTime
            })
            .select()
            .single();

        if (insertError) throw insertError;

        // 3. Update main recipe record with latest version info
        const { error: updateError } = await req.supabase
            .from('recipes')
            .update({
                title,
                description,
                ingredients,
                instructions,
                chefs_note: chefsNote,
                step0_summary: step0Summary,
                step0_audio_url: step0AudioUrl,
                difficulty,
                cooking_time: cookingTime,
                updated_at: new Date().toISOString()
            })
            .eq('id', recipeId);

        if (updateError) throw updateError;

        console.log(`Saved version ${nextVersion} for recipe ${recipeId}`);
        res.json({ success: true, version: vData });
    } catch (error: any) {
        console.error("Error saving version:", error);
        res.status(500).json({ error: error.message });
    }
});

export default router;
