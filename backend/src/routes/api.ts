import express, { Request, Response } from 'express';
import { VideoDownloader } from '../services/video_downloader';
import { GeminiService } from '../services/gemini_service';
import { StorageService } from '../services/storage';
import { db } from '../db/firebase';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

const videoDownloader = new VideoDownloader();
const geminiService = new GeminiService();
const storageService = new StorageService();

router.post('/share', async (req: Request, res: Response) => {
    try {
        const { url, userId } = req.body;

        if (!url || !userId) {
            return res.status(400).json({ error: 'Missing url or userId' });
        }

        console.log(`Processing share for User: ${userId}, URL: ${url}`);

        // 1. Download VIdeo
        const videoMeta = await videoDownloader.downloadVideo(url);

        // 2. Upload to Persistent Storage
        const filename = `${uuidv4()}.mp4`;
        const storageUrl = await storageService.uploadVideoFromUrl(videoMeta.url, filename);

        // 3. Process with Gemini
        // We pass the storage URL (or gs:// URI if Gemini supports it directly from the same project)
        const recipeData = await geminiService.extractRecipe(storageUrl);

        // 4. Save to Firestore
        const recipeId = uuidv4();
        const newRecipe = {
            id: recipeId,
            userId,
            originalUrl: url,
            videoUrl: storageUrl,
            metadata: videoMeta,
            ...recipeData,
            createdAt: new Date().toISOString()
        };

        await db.collection('recipes').doc(recipeId).set(newRecipe);

        res.status(200).json({ success: true, recipeId, message: 'Recipe processed successfully' });

    } catch (error: any) {
        console.error('Error processing share:', error);
        res.status(500).json({ error: error.message || 'Internal Server Error' });
    }
});

router.get('/recipes', async (req: Request, res: Response) => {
    try {
        const snapshot = await db.collection('recipes').orderBy('createdAt', 'desc').get();
        const recipes = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        res.status(200).json(recipes);
    } catch (error: any) {
        console.error('Error fetching recipes:', error);
        res.status(500).json({ error: error.message });
    }
});

export default router;
