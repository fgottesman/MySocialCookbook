
import axios from 'axios';
import fs from 'fs';
import path from 'path';

const DOWNLOAD_DIR = path.resolve(__dirname, '../../downloads');

// Ensure download dir exists
if (!fs.existsSync(DOWNLOAD_DIR)) {
    fs.mkdirSync(DOWNLOAD_DIR, { recursive: true });
}

export class VideoDownloader {

    async downloadVideo(url: string): Promise<string> {
        const rapidApiKey = process.env.RAPIDAPI_KEY;

        if (!rapidApiKey) {
            throw new Error("Missing RAPIDAPI_KEY in environment");
        }

        console.log(`Downloading video via RapidAPI: ${url}`);

        // Detect platform and use appropriate API
        const isTikTok = url.includes('tiktok.com');
        const isInstagram = url.includes('instagram.com');
        const isYouTube = url.includes('youtube.com') || url.includes('youtu.be');

        let downloadUrl: string | null = null;

        try {
            if (isTikTok) {
                downloadUrl = await this.downloadTikTok(url, rapidApiKey);
            } else if (isInstagram) {
                downloadUrl = await this.downloadInstagram(url, rapidApiKey);
            } else if (isYouTube) {
                // For YouTube, we'll use a different approach or skip for now
                throw new Error("YouTube videos are not yet supported. Please share TikTok or Instagram videos.");
            } else {
                // Try generic approach
                downloadUrl = await this.downloadGeneric(url, rapidApiKey);
            }

            if (!downloadUrl) {
                throw new Error("Could not retrieve download URL");
            }

            console.log("Got direct URL:", downloadUrl);

            // Download the actual file stream
            const fileResponse = await axios({
                url: downloadUrl,
                method: 'GET',
                responseType: 'stream',
                timeout: 120000, // 2 minute timeout for large files
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
                }
            });

            const filename = `${Date.now()}.mp4`;
            const filePath = path.join(DOWNLOAD_DIR, filename);

            const writer = fs.createWriteStream(filePath);
            fileResponse.data.pipe(writer);

            return new Promise((resolve, reject) => {
                writer.on('finish', () => {
                    console.log(`Video downloaded to: ${filePath}`);
                    resolve(filePath);
                });
                writer.on('error', reject);
            });

        } catch (e: any) {
            console.error("Video Download Failed", e.response?.data || e.message);
            throw e;
        }
    }

    private async downloadTikTok(url: string, apiKey: string): Promise<string> {
        // Using TikTok Video Downloader API
        // https://rapidapi.com/yi005/api/tiktok-video-downloader
        const options = {
            method: 'GET',
            url: 'https://tiktok-video-downloader.p.rapidapi.com/media',
            params: { url: url },
            headers: {
                'x-rapidapi-key': apiKey,
                'x-rapidapi-host': 'tiktok-video-downloader.p.rapidapi.com'
            }
        };

        const response = await axios.request(options);
        console.log("TikTok API Response:", JSON.stringify(response.data, null, 2));

        // Extract video URL from response
        return response.data?.video_url || response.data?.data?.play || null;
    }

    private async downloadInstagram(url: string, apiKey: string): Promise<string> {
        // Using Save Insta API
        // https://rapidapi.com/maatootz/api/save-insta1
        const options = {
            method: 'GET',
            url: 'https://save-insta1.p.rapidapi.com/media',
            params: { url: url },
            headers: {
                'x-rapidapi-key': apiKey,
                'x-rapidapi-host': 'save-insta1.p.rapidapi.com'
            }
        };

        const response = await axios.request(options);
        console.log("Instagram API Response:", JSON.stringify(response.data, null, 2));

        // Extract video URL from response
        if (response.data?.links && Array.isArray(response.data.links)) {
            const videoLink = response.data.links.find((l: any) => l.type === 'video');
            return videoLink?.url || response.data.links[0]?.url || null;
        }
        return response.data?.video_url || null;
    }

    private async downloadGeneric(url: string, apiKey: string): Promise<string> {
        // Fall back to All-in-One downloader
        const options = {
            method: 'GET',
            url: 'https://auto-download-all-in-one.p.rapidapi.com/v1/social/autolink',
            params: { url: url },
            headers: {
                'x-rapidapi-key': apiKey,
                'x-rapidapi-host': 'auto-download-all-in-one.p.rapidapi.com'
            }
        };

        const response = await axios.request(options);
        console.log("Generic API Response:", JSON.stringify(response.data, null, 2));

        // Extract video URL from response
        if (response.data?.medias && Array.isArray(response.data.medias)) {
            return response.data.medias[0]?.url || null;
        }
        return response.data?.url || null;
    }
}
