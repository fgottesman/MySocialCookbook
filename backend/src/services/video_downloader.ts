
import axios from 'axios';
import fs from 'fs';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';

export class VideoDownloader {

    /**
     * Downloads a video from TikTok, Instagram, or other social platforms
     * using the "Auto Download All In One" API (FastSaverAPI) from RapidAPI.
     * 
     * Subscribe at: https://rapidapi.com/FastSaverAPI/api/auto-download-all-in-one
     */
    async downloadVideo(url: string): Promise<string> {
        const rapidApiKey = process.env.RAPIDAPI_KEY;

        if (!rapidApiKey) {
            throw new Error("RAPIDAPI_KEY environment variable is not set");
        }

        console.log("Downloading video via FastSaverAPI:", url);

        try {
            // FastSaverAPI - Auto Download All In One
            // Supports: Instagram, TikTok, YouTube, Facebook, Twitter, Pinterest, and more
            const response = await axios.get('https://auto-download-all-in-one.p.rapidapi.com/v1/social/autolink', {
                headers: {
                    'x-rapidapi-key': rapidApiKey,
                    'x-rapidapi-host': 'auto-download-all-in-one.p.rapidapi.com'
                },
                params: {
                    url: url
                }
            });

            console.log("FastSaverAPI response:", JSON.stringify(response.data, null, 2));

            // Extract download URL from response
            let downloadUrl: string | null = null;

            // Handle different response formats
            if (response.data?.medias && response.data.medias.length > 0) {
                // Find the best quality video
                const videoMedia = response.data.medias.find((m: any) =>
                    m.type === 'video' || m.videoAvailable || m.url
                );
                if (videoMedia) {
                    downloadUrl = videoMedia.url || videoMedia.videoUrl;
                }
            } else if (response.data?.url) {
                downloadUrl = response.data.url;
            } else if (response.data?.videoUrl) {
                downloadUrl = response.data.videoUrl;
            } else if (response.data?.downloadUrl) {
                downloadUrl = response.data.downloadUrl;
            }

            if (!downloadUrl) {
                console.error("No download URL found in response:", response.data);
                throw new Error("Could not extract video download URL from API response");
            }

            console.log("Video URL found:", downloadUrl);

            // Download the actual video file
            const videoResponse = await axios.get(downloadUrl, {
                responseType: 'arraybuffer',
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
                }
            });

            // Save to local file
            const downloadDir = path.join(__dirname, '../../downloads');
            if (!fs.existsSync(downloadDir)) {
                fs.mkdirSync(downloadDir, { recursive: true });
            }

            const fileName = `${uuidv4()}.mp4`;
            const filePath = path.join(downloadDir, fileName);
            fs.writeFileSync(filePath, videoResponse.data);

            console.log("Video saved to:", filePath);
            return filePath;

        } catch (error: any) {
            if (error.response) {
                console.error("Video Download Failed", error.response.data);

                // Provide helpful error message for subscription issues
                if (error.response.status === 403) {
                    throw new Error(
                        "RapidAPI subscription required. Please subscribe to 'Auto Download All In One' API at: " +
                        "https://rapidapi.com/FastSaverAPI/api/auto-download-all-in-one"
                    );
                }
            }
            throw error;
        }
    }
}
