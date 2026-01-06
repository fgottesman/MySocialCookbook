
import axios from 'axios';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

export class VideoDownloader {

    /**
     * Downloads a video from TikTok, Instagram, or other social platforms
     * using the "Social Download All in One" API from RapidAPI.
     * 
     * Subscribe at: https://rapidapi.com/nguyenmanhict-MuTUtGWD7K/api/social-download-all-in-one
     */
    async fetchVideoMetadata(url: string): Promise<{ downloadUrl: string, thumbnailUrl: string | null, description?: string, mediaType: 'video' | 'image' }> {
        const rapidApiKey = process.env.RAPIDAPI_KEY;

        if (!rapidApiKey) {
            throw new Error("RAPIDAPI_KEY environment variable is not set");
        }

        console.log("Fetching video metadata via Social Download All in One API:", url);

        try {
            const response = await axios.post('https://social-download-all-in-one.p.rapidapi.com/v1/social/autolink',
                { url: url },
                {
                    headers: {
                        'x-rapidapi-key': rapidApiKey,
                        'x-rapidapi-host': 'social-download-all-in-one.p.rapidapi.com',
                        'Content-Type': 'application/json'
                    }
                }
            );

            console.log("API response:", JSON.stringify(response.data, null, 2));

            let downloadUrl: string | null = null;
            let thumbnailUrl: string | null = null;
            let description: string | null = response.data?.title || response.data?.description || null;
            let mediaType: 'video' | 'image' = 'video';

            if (response.data?.medias && response.data.medias.length > 0) {
                // Look for images first if it's a photo mode post
                const imageMedia = response.data.medias.find((m: any) => m.type === 'image' || m.extension === 'webp' || m.extension === 'jpg');
                const videoMedia = response.data.medias.find((m: any) => m.type === 'video' || m.videoAvailable);

                if (imageMedia && !videoMedia) {
                    mediaType = 'image';
                    downloadUrl = imageMedia.url;
                } else if (videoMedia) {
                    mediaType = 'video';
                    downloadUrl = videoMedia.url || videoMedia.videoUrl;
                }

                thumbnailUrl = response.data.cover || response.data.thumbnail || null;
            }

            if (!downloadUrl) {
                if (response.data?.url) {
                    downloadUrl = response.data.url;
                } else if (response.data?.videoUrl) {
                    downloadUrl = response.data.videoUrl;
                } else if (response.data?.downloadUrl) {
                    downloadUrl = response.data.downloadUrl;
                } else if (response.data?.video) {
                    downloadUrl = response.data.video;
                }
            }

            // Fallback for thumbnail
            if (!thumbnailUrl) {
                if (response.data?.cover) {
                    thumbnailUrl = response.data.cover;
                } else if (response.data?.thumbnail) {
                    thumbnailUrl = response.data.thumbnail;
                } else if (response.data?.picture) {
                    thumbnailUrl = response.data.picture;
                }
            }

            if (!downloadUrl) {
                console.error("No download URL found in response:", response.data);
                throw new Error("Could not extract video download URL from API response");
            }

            console.log("Media URL found:", downloadUrl);
            console.log("Media type:", mediaType);
            console.log("Description found:", description?.substring(0, 50) + "...");

            return {
                downloadUrl,
                thumbnailUrl,
                description: description || undefined,
                mediaType
            };

        } catch (error: any) {
            if (error.response) {
                console.error("Video Metadata Fetch Failed", error.response.data);
                if (error.response.status === 403) {
                    throw new Error(
                        "RapidAPI subscription required. Please subscribe to 'Social Download All in One' API at: " +
                        "https://rapidapi.com/nguyenmanhict-MuTUtGWD7K/api/social-download-all-in-one"
                    );
                }
            }
            throw error;
        }
    }

    async downloadMedia(url: string): Promise<{ filePath: string, thumbnailUrl: string | null, description?: string, mimeType: string }> {
        const { downloadUrl, thumbnailUrl, description, mediaType } = await this.fetchVideoMetadata(url);

        try {
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

            const extension = mediaType === 'image' ? 'jpg' : 'mp4';
            const fileName = `${crypto.randomUUID()}.${extension}`;
            const filePath = path.join(downloadDir, fileName);
            fs.writeFileSync(filePath, videoResponse.data);

            const mimeType = mediaType === 'image' ? 'image/jpeg' : 'video/mp4';
            console.log(`${mediaType} saved to:`, filePath);
            return { filePath, thumbnailUrl, description, mimeType };
        } catch (error) {
            console.error("Video File Download Failed", error);
            throw error;
        }
    }

    async downloadThumbnail(url: string, outputPath: string): Promise<string> {
        console.log("Downloading thumbnail from:", url);
        try {
            const response = await axios.get(url, {
                responseType: 'arraybuffer',
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
                }
            });

            fs.writeFileSync(outputPath, response.data);
            console.log("Thumbnail saved to:", outputPath);
            return outputPath;
        } catch (error) {
            console.error("Failed to download thumbnail:", error);
            throw error;
        }
    }
}
