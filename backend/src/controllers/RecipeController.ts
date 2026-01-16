import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { GeminiService } from '../services/gemini';
import { VideoDownloader } from '../services/video_downloader';
import { WebRecipeScraper } from '../services/web_recipe_scraper';
import { ttsService } from '../services/tts';
import { apnsService } from '../services/apns';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import logger from '../utils/logger';

const downloader = new VideoDownloader();
const webScraper = new WebRecipeScraper();
const gemini = new GeminiService();

export class RecipeController {
    static async processRecipe(req: AuthRequest, res: Response) {
        const { url } = req.body as { url: string };
        const userId = req.user.id;

        res.json({ success: true, message: 'Processing started' });

        try {
            if (!url || !userId) return;

            logger.info(`Processing recipe for user ${userId} from ${url}`);

            let recipeData;
            let finalDescription: string | undefined;
            let creatorUsername: string | undefined;

            // Check if this is a web recipe URL (not a video)
            if (WebRecipeScraper.isWebRecipeUrl(url)) {
                logger.info('Detected web recipe URL, using web scraper');
                const webData = await webScraper.scrapeRecipe(url);
                recipeData = await gemini.generateRecipeFromWebpage(webData);
                recipeData.thumbnailUrl = webData.imageUrl;
                creatorUsername = webData.author;
            } else if (RecipeController.isDirectProcessableUrl(url)) {
                try {
                    recipeData = await gemini.generateRecipeFromURL(url);
                } catch (err) {
                    logger.info("Direct processing failed, falling back to download");
                    const media = await downloader.downloadMedia(url);
                    recipeData = await gemini.generateRecipe(media.filePath, media.mimeType, media.description);
                    recipeData.thumbnailUrl = media.thumbnailUrl; // Capture thumbnail from media
                    finalDescription = media.description;
                    creatorUsername = media.creatorUsername;
                    if (fs.existsSync(media.filePath)) fs.unlinkSync(media.filePath);
                }
            } else {
                const media = await downloader.downloadMedia(url);
                recipeData = await gemini.generateRecipe(media.filePath, media.mimeType, media.description);
                recipeData.thumbnailUrl = media.thumbnailUrl; // Capture thumbnail from media
                creatorUsername = media.creatorUsername;
                if (fs.existsSync(media.filePath)) fs.unlinkSync(media.filePath);
            }

            // Handle Thumbnail Persistence
            if (recipeData.thumbnailUrl) {
                recipeData.thumbnailUrl = await RecipeController.persistThumbnail(req, recipeData.thumbnailUrl);
            }

            // Generate Embedding
            const embeddingText = `${recipeData.title} ${recipeData.description} ${finalDescription || ''} ${recipeData.ingredients.map((i: any) => i.name).join(' ')}`;
            const embedding = await gemini.generateEmbedding(embeddingText);

            // Handle Step 0 Audio
            let step0AudioUrl = null;
            if (recipeData.step0Summary) {
                step0AudioUrl = await RecipeController.generateStep0Audio(req, recipeData.step0Summary);
            }

            // Save to DB
            const { data, error } = await req.supabase
                .from('recipes')
                .insert({
                    user_id: userId,
                    title: recipeData.title,
                    description: recipeData.description,
                    ingredients: recipeData.ingredients,
                    instructions: recipeData.instructions,
                    thumbnail_url: recipeData.thumbnailUrl,
                    video_url: url, // FIX: Map specifically to video_url for iOS attribution
                    source_url: url, // Keep this for redundancy since we added the column
                    embedding: embedding,
                    step0_summary: recipeData.step0Summary,
                    step0_audio_url: step0AudioUrl,
                    difficulty: recipeData.difficulty,
                    cooking_time: recipeData.cookingTime,
                    creator_username: creatorUsername
                })
                .select()
                .single();

            if (error) throw error;

            // Increment credits used
            // We import dynamically to avoid circular dependencies if any, or just standard import
            const { incrementRecipeCredits } = await import('../middleware/subscriptionMiddleware');
            await incrementRecipeCredits(userId);

            await RecipeController.notifyUser(req, userId, 'Recipe Ready! 🍳', `"${recipeData.title}" is ready to cook.`, data.id);

            // Background pre-compute
            RecipeController.preComputeSteps(req, data.id, recipeData);

        } catch (error) {
            logger.error("Process Recipe Error:", error);
        }
    }

    static async getFeed(req: AuthRequest, res: Response) {
        const { data, error } = await req.supabase
            .from('recipes')
            .select('*, profiles(*)')
            .order('created_at', { ascending: false });

        if (error) return res.status(500).json({ error: error.message });
        res.json(data);
    }

    static async deleteRecipe(req: AuthRequest, res: Response) {
        const { id } = req.params;
        const userId = req.user.id;

        const { error } = await req.supabase
            .from('recipes')
            .delete()
            .eq('id', id)
            .eq('user_id', userId);

        if (error) return res.status(500).json({ error: error.message });
        res.json({ success: true });
    }

    // Helpers extracted from api.ts
    private static isDirectProcessableUrl(url: string): boolean {
        return url.includes('youtube.com') || url.includes('youtu.be') || url.includes('instagram.com') || url.includes('tiktok.com');
    }

    private static async persistThumbnail(req: AuthRequest, url: string): Promise<string> {
        try {
            const thumbName = `thumb_${crypto.randomUUID()}.jpg`;
            const downloadDir = path.join(__dirname, '../../downloads');
            if (!fs.existsSync(downloadDir)) fs.mkdirSync(downloadDir);
            const thumbPath = path.join(downloadDir, thumbName);

            await downloader.downloadThumbnail(url, thumbPath);
            const { data, error } = await req.supabase.storage
                .from('recipe-thumbnails')
                .upload(thumbName, fs.readFileSync(thumbPath), { contentType: 'image/jpeg', upsert: true });

            if (fs.existsSync(thumbPath)) fs.unlinkSync(thumbPath);
            if (error) throw error;

            return req.supabase.storage.from('recipe-thumbnails').getPublicUrl(thumbName).data.publicUrl;
        } catch (e) {
            return url;
        }
    }

    private static async generateStep0Audio(req: AuthRequest, text: string): Promise<string | null> {
        try {
            const audioBase64 = await ttsService.synthesize(text);
            const audioName = `audio_${crypto.randomUUID()}.mp3`;
            const audioBuffer = Buffer.from(audioBase64, 'base64');
            const { error } = await req.supabase.storage.from('recipe-thumbnails').upload(audioName, audioBuffer, { contentType: 'audio/mpeg', upsert: true });
            if (error) throw error;
            return req.supabase.storage.from('recipe-thumbnails').getPublicUrl(audioName).data.publicUrl;
        } catch (e) {
            return null;
        }
    }

    private static async notifyUser(req: AuthRequest, userId: string, title: string, body: string, recipeId?: string) {
        const { data: devices } = await req.supabase.from('user_devices').select('device_token').eq('user_id', userId).eq('platform', 'ios');
        if (devices) {
            for (const device of devices) {
                await apnsService.sendNotification(device.device_token, { title, body, recipeId });
            }
        }
    }

    static async getVersions(req: AuthRequest, res: Response) {
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
            res.status(500).json({ error: error.message });
        }
    }

    static async saveVersion(req: AuthRequest, res: Response) {
        try {
            const { recipeId } = req.params;
            const { title, description, ingredients, instructions, chefsNote, changedIngredients, step0Summary, step0AudioUrl, difficulty, cookingTime } = req.body;

            // Use a retry mechanism for handling concurrent version creation
            const MAX_RETRIES = 3;
            let retryCount = 0;
            let vData = null;

            while (retryCount < MAX_RETRIES && !vData) {
                try {
                    // 1. Get the latest version number in a single atomic query
                    const { data: latestVersion, error: vError } = await req.supabase
                        .from('recipe_versions')
                        .select('version_number')
                        .eq('recipe_id', recipeId)
                        .order('version_number', { ascending: false })
                        .limit(1)
                        .single();

                    let nextVersion = 1;
                    let needsOriginalSnapshot = false;

                    if (vError?.code === 'PGRST116') {
                        // No versions exist - need to create original snapshot first
                        needsOriginalSnapshot = true;
                        nextVersion = 2; // Remix will be version 2
                    } else if (vError) {
                        throw vError;
                    } else {
                        nextVersion = latestVersion.version_number + 1;
                    }

                    // If this is the first remix, snapshot the original
                    if (needsOriginalSnapshot) {
                        logger.info(`First remix for recipe ${recipeId}. Creating original snapshot as v1.`);

                        // Fetch original recipe
                        const { data: originalRecipe, error: fetchError } = await req.supabase
                            .from('recipes')
                            .select('*')
                            .eq('id', recipeId)
                            .single();

                        if (fetchError) throw fetchError;

                        // Try to insert original as version 1
                        // Use upsert=false to fail if it already exists (concurrent request created it)
                        const { error: snapshotError } = await req.supabase
                            .from('recipe_versions')
                            .insert({
                                recipe_id: recipeId,
                                version_number: 1,
                                title: "Original",
                                description: originalRecipe.description,
                                ingredients: originalRecipe.ingredients,
                                instructions: originalRecipe.instructions,
                                chefs_note: originalRecipe.chefs_note,
                                changed_ingredients: [],
                                step0_summary: originalRecipe.step0_summary,
                                step0_audio_url: originalRecipe.step0_audio_url,
                                difficulty: originalRecipe.difficulty,
                                cooking_time: originalRecipe.cooking_time,
                                created_at: originalRecipe.created_at
                            });

                        // If snapshot fails with duplicate key, another request already created it
                        // Continue to create the remix version
                        if (snapshotError && !snapshotError.message.includes('duplicate')) {
                            throw snapshotError;
                        }
                    }

                    // 2. Insert the new version with the calculated version number
                    const { data: insertedVersion, error: insertError } = await req.supabase
                        .from('recipe_versions')
                        .insert({
                            recipe_id: recipeId,
                            version_number: nextVersion,
                            title,
                            description,
                            ingredients,
                            instructions,
                            chefs_note: chefsNote,
                            changed_ingredients: changedIngredients,
                            step0_summary: step0Summary,
                            step0_audio_url: step0AudioUrl,
                            difficulty,
                            cooking_time: cookingTime
                        })
                        .select()
                        .single();

                    if (insertError) {
                        // Check if it's a unique constraint violation (concurrent insert)
                        if (insertError.message.includes('duplicate') || insertError.code === '23505') {
                            logger.warn(`Concurrent version creation detected for recipe ${recipeId}, retrying...`);
                            retryCount++;
                            await new Promise(resolve => setTimeout(resolve, 100 * retryCount)); // Exponential backoff
                            continue;
                        }
                        throw insertError;
                    }

                    vData = insertedVersion;
                    logger.info(`Successfully created version ${nextVersion} for recipe ${recipeId}`);

                } catch (error: any) {
                    if (retryCount >= MAX_RETRIES - 1) {
                        throw error;
                    }
                    retryCount++;
                    logger.warn(`Retry ${retryCount}/${MAX_RETRIES} for version creation: ${error.message}`);
                    await new Promise(resolve => setTimeout(resolve, 100 * retryCount));
                }
            }

            if (!vData) {
                throw new Error('Failed to create version after maximum retries');
            }

            // 3. DO NOT Update the Parent Recipe
            // User Feedback: "I don't want to change the feed card, keep that as the original."
            // The feed will continue to show the original recipe info.
            // When the user opens the recipe, the versions will load and auto-select the latest remix.

            res.json({ success: true, version: vData });
        } catch (error: any) {
            logger.error(`Save Version Error: ${error.message}`, { recipeId: req.params.recipeId });
            res.status(500).json({ error: error.message });
        }
    }

    static async toggleFavorite(req: AuthRequest, res: Response) {
        let recipeId: string | undefined;
        try {
            const { id } = req.params;
            recipeId = id;
            const { isFavorite } = req.body;
            const userId = req.user.id;

            const { data, error } = await req.supabase
                .from('recipes')
                .update({ is_favorite: isFavorite })
                .eq('id', id)
                .eq('user_id', userId)
                .select()
                .single();

            if (error) throw error;
            res.json(data);
        } catch (error: any) {
            logger.error(`Favorite Toggle Error: ${error.message}`, { recipeId });
            res.status(500).json({ error: error.message });
        }
    }

    private static async preComputeSteps(req: AuthRequest, recipeId: string, recipeData: any) {
        try {
            logger.info(`Starting background pre-computation for recipe ${recipeId}`);
            const stepPreparations = await gemini.prepareAllSteps({
                title: recipeData.title,
                ingredients: recipeData.ingredients,
                instructions: recipeData.instructions
            });

            const { error } = await req.supabase
                .from('recipes')
                .update({ step_preparations: stepPreparations })
                .eq('id', recipeId);

            if (error) logger.error(`Error saving pre-computed steps for ${recipeId}: ${error.message}`);
            else logger.info(`Step preparations saved for recipe ${recipeId}`);
        } catch (prepError: any) {
            logger.error(`Error pre-computing step preparations for ${recipeId}: ${prepError.message}`);
        }
    }
}
