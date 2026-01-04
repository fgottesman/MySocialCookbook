import { storage } from '../db/firebase';
import axios from 'axios';
import fs from 'fs';
import path from 'path';
import os from 'os';

export class StorageService {
    private bucketName: string;

    constructor() {
        this.bucketName = process.env.FIREBASE_STORAGE_BUCKET || 'my-social-cookbook.appspot.com';
    }

    async uploadVideoFromUrl(videoUrl: string, destinationFilename: string): Promise<string> {
        console.log(`Uploading video to storage: ${destinationFilename}`);

        // 1. Download to temp file
        const tempFilePath = path.join(os.tmpdir(), destinationFilename);
        const writer = fs.createWriteStream(tempFilePath);

        const response = await axios({
            url: videoUrl,
            method: 'GET',
            responseType: 'stream'
        });

        response.data.pipe(writer);

        await new Promise((resolve, reject) => {
            writer.on('finish', () => resolve(true));
            writer.on('error', reject);
        });

        // 2. Upload to Firebase Storage
        const bucket = storage.bucket(this.bucketName);
        await bucket.upload(tempFilePath, {
            destination: `videos/${destinationFilename}`,
            metadata: {
                contentType: 'video/mp4',
            }
        });

        // 3. Cleanup
        fs.unlinkSync(tempFilePath);

        // 4. Get public URL (or signed URL)
        // For simpler access control in this MVP, we might assume the bucket is private but we generate a signed URL
        // or make the file public. Let's make it public for now or use signed URL.
        const file = bucket.file(`videos/${destinationFilename}`);
        const [url] = await file.getSignedUrl({
            action: 'read',
            expires: '03-01-2500' // Far future
        });

        return url;
    }
}
