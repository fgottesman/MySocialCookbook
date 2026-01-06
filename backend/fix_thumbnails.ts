
import dotenv from 'dotenv';
dotenv.config();

import { supabase } from './src/db/supabase';
import { VideoDownloader } from './src/services/video_downloader';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

async function fixThumbnails() {
    console.log("Starting thumbnail fix process...");

    // 1. Ensure Bucket Exists
    const BUCKET_NAME = 'recipe-thumbnails';
    const { data: buckets, error: bucketError } = await supabase.storage.listBuckets();

    if (bucketError) {
        console.error("Error listing buckets:", bucketError);
        return;
    }

    const bucketExists = buckets.find(b => b.name === BUCKET_NAME);

    if (!bucketExists) {
        console.log(`Bucket '${BUCKET_NAME}' not found. Creating...`);
        const { data, error } = await supabase.storage.createBucket(BUCKET_NAME, {
            public: true
        });
        if (error) {
            console.error("Failed to create bucket:", error);
            // Try to proceed anyway, maybe it exists but permissions obscured it (unlikely with service role)
        } else {
            console.log(`Bucket '${BUCKET_NAME}' created.`);
        }
    } else {
        console.log(`Bucket '${BUCKET_NAME}' exists.`);
    }

    // 2. Fetch all recipes
    const { data: recipes, error: recipeError } = await supabase
        .from('recipes')
        .select('*');

    if (recipeError || !recipes) {
        console.error("Error fetching recipes:", recipeError);
        return;
    }

    console.log(`Found ${recipes.length} recipes. Checking for broken thumbnails...`);

    const downloader = new VideoDownloader();
    const tempDir = path.join(__dirname, 'temp_thumbs');
    if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir);
    }

    for (const recipe of recipes) {
        const currentThumb = recipe.thumbnail_url;

        // Skip if it looks like a permanent Supabase URL already
        if (currentThumb && currentThumb.includes(BUCKET_NAME)) {
            console.log(`Skipping recipe "${recipe.title}" (already fixed)`);
            continue;
        }

        console.log(`Fixing thumbnail for "${recipe.title}" (ID: ${recipe.id})...`);

        try {
            if (!recipe.video_url) {
                console.warn("No video_url, skipping.");
                continue;
            }

            // A. Fetch fresh metadata to get a working thumbnail URL
            console.log("Fetching fresh metadata from:", recipe.video_url);
            const { thumbnailUrl: freshRemoteUrl } = await downloader.fetchVideoMetadata(recipe.video_url);

            if (!freshRemoteUrl) {
                console.warn("No thumbnail URL returned from API, skipping.");
                continue;
            }

            // B. Download to temp file
            const fileName = `thumb_${recipe.id}_${crypto.randomUUID().split('-')[0]}.jpg`;
            const filePath = path.join(tempDir, fileName);
            await downloader.downloadThumbnail(freshRemoteUrl, filePath);

            // C. Upload to Supabase
            const fileBuffer = fs.readFileSync(filePath);
            const { error: uploadError } = await supabase.storage
                .from(BUCKET_NAME)
                .upload(fileName, fileBuffer, {
                    contentType: 'image/jpeg',
                    upsert: true
                });

            if (uploadError) {
                console.error("Upload failed:", uploadError);
                continue;
            }

            // D. Get Public URL
            const { data: publicUrlData } = supabase.storage
                .from(BUCKET_NAME)
                .getPublicUrl(fileName);

            const newPermanentUrl = publicUrlData.publicUrl;
            console.log("New persistent URL:", newPermanentUrl);

            // E. Update Database
            const { error: updateError } = await supabase
                .from('recipes')
                .update({ thumbnail_url: newPermanentUrl })
                .eq('id', recipe.id);

            if (updateError) {
                console.error("Database update failed:", updateError);
            } else {
                console.log("SUCCESS: Thumbnail updated for", recipe.title);
            }

            // Cleanup
            fs.unlinkSync(filePath);

        } catch (err: any) {
            console.error(`Failed to process recipe ${recipe.id}:`, err.message);
        }
    }

    // Cleanup temp dir
    if (fs.existsSync(tempDir)) {
        fs.rmdirSync(tempDir); // works if empty
    }
    console.log("Thumbnail fix process completed.");
}

fixThumbnails().catch(console.error);
