
import axios from 'axios';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import logger from '../utils/logger';

export class VideoDownloader {

    /**
     * Downloads a video from TikTok, Instagram, or other social platforms
     * using the "Social Download All in One" API from RapidAPI.
     * 
     * Subscribe at: https://rapidapi.com/nguyenmanhict-MuTUtGWD7K/api/social-download-all-in-one
     */
    async fetchVideoMetadata(url: string): Promise<{ downloadUrl: string, thumbnailUrl: string | null, description?: string, mediaType: 'video' | 'image', creatorUsername?: string }> {
        const rapidApiKey = process.env.RAPIDAPI_KEY;

        if (!rapidApiKey) {
            throw new Error("RAPIDAPI_KEY environment variable is not set");
        }

        logger.info(`Fetching video metadata via Social Download All in One API: ${url}`);

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

            logger.debug("RapidAPI response received successfully");

            let downloadUrl: string | null = null;
            let thumbnailUrl: string | null = null;
            let description: string | null = response.data?.title || response.data?.description || null;
            let mediaType: 'video' | 'image' = 'video';


            // Extract creator username from various possible fields (with error handling)
            let creatorUsername: string | null = null;
            try {
                const data = response.data;
                if (data?.author) {
                    creatorUsername = typeof data.author === 'string' ? data.author : data.author?.username || data.author?.name || data.author?.unique_id;
                } else if (data?.username) {
                    creatorUsername = data.username;
                } else if (data?.user) {
                    creatorUsername = typeof data.user === 'string' ? data.user : data.user?.username || data.user?.name;
                } else if (data?.creator) {
                    creatorUsername = typeof data.creator === 'string' ? data.creator : data.creator?.username || data.creator?.name;
                } else if (data?.owner) {
                    creatorUsername = typeof data.owner === 'string' ? data.owner : data.owner?.username || data.owner?.name;
                }

                // Validate and sanitize username
                if (creatorUsername) {
                    creatorUsername = String(creatorUsername).trim();
                    // Remove Unicode control/bidirectional characters and other potentially dangerous chars
                    creatorUsername = creatorUsername.replace(/[\u0000-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\uFEFF]/g, '');
                    // Allow alphanumeric, spaces, underscores, periods, hyphens, @ (common in social handles)
                    creatorUsername = creatorUsername.replace(/[^a-zA-Z0-9\s_.@-]/g, '');
                    // Truncate very long usernames (social media usernames are typically <30 chars)
                    if (creatorUsername.length > 50) {
                        creatorUsername = creatorUsername.substring(0, 50);
                    }
                    // Handle empty strings
                    if (creatorUsername.length === 0) {
                        creatorUsername = null;
                    }
                }
            } catch (extractionError) {
                logger.warn('Failed to extract creator username', { error: extractionError });
                creatorUsername = null;
            }

            if (creatorUsername) {
                // Redact PII in logs for privacy compliance
                logger.info(`Creator username extracted: [${creatorUsername.length} chars]`);
            }

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
                logger.error("No download URL found in response", { data: response.data });
                throw new Error("Could not extract video download URL from API response");
            }

            logger.info("Media metadata found", {
                mediaType,
                description: description?.substring(0, 50),
                creatorUsername
            });

            return {
                downloadUrl,
                thumbnailUrl,
                description: description || undefined,
                mediaType,
                creatorUsername: creatorUsername || undefined
            };

        } catch (error: any) {
            if (error.response) {
                logger.error("Video Metadata Fetch Failed", { error: error.response.data });
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

    async downloadMedia(url: string): Promise<{ filePath: string, thumbnailUrl: string | null, description?: string, mimeType: string, creatorUsername?: string }> {
        const { downloadUrl, thumbnailUrl, description, mediaType, creatorUsername } = await this.fetchVideoMetadata(url);

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
            logger.info(`${mediaType} saved successfully`, { filePath });
            return { filePath, thumbnailUrl, description, mimeType, creatorUsername };
        } catch (error) {
            logger.error("Video File Download Failed", { error });
            throw error;
        }
    }

    async downloadThumbnail(url: string, outputPath: string): Promise<string> {
        logger.info(`Downloading thumbnail from: ${url}`);
        try {
            const response = await axios.get(url, {
                responseType: 'arraybuffer',
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
                }
            });

            fs.writeFileSync(outputPath, response.data);
            logger.info(`Thumbnail saved to: ${outputPath}`);
            return outputPath;
        } catch (error) {
            logger.error("Failed to download thumbnail", { error });
            throw error;
        }
    }
}
