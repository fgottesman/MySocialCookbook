import { TextToSpeechClient } from '@google-cloud/text-to-speech';
import logger from '../utils/logger';

/**
 * Google Cloud Text-to-Speech Service
 *
 * IMPORTANT: This service requires Google Cloud Platform credentials, NOT Gemini API keys.
 * Configure ONE of the following:
 * 1. GOOGLE_TTS_API_KEY - A GCP API key with Text-to-Speech API enabled
 * 2. GOOGLE_APPLICATION_CREDENTIALS - Path to a service account JSON file
 */
export class TTSService {
    private client: TextToSpeechClient | null = null;
    private isAvailable: boolean = false;
    private initError: string | null = null;

    constructor() {
        this.initializeClient();
    }

    private initializeClient() {
        // Check for dedicated TTS API key first
        const ttsApiKey = process.env.GOOGLE_TTS_API_KEY;

        // Check for service account credentials
        const hasServiceAccount = !!process.env.GOOGLE_APPLICATION_CREDENTIALS;

        if (ttsApiKey) {
            try {
                this.client = new TextToSpeechClient({
                    apiKey: ttsApiKey
                });
                this.isAvailable = true;
                logger.info('TTS Service initialized with API key');
            } catch (error: any) {
                this.initError = `TTS init failed with API key: ${error.message}`;
                logger.warn(this.initError);
            }
        } else if (hasServiceAccount) {
            try {
                // Will automatically use GOOGLE_APPLICATION_CREDENTIALS
                this.client = new TextToSpeechClient();
                this.isAvailable = true;
                logger.info('TTS Service initialized with service account');
            } catch (error: any) {
                this.initError = `TTS init failed with service account: ${error.message}`;
                logger.warn(this.initError);
            }
        } else {
            this.initError = 'TTS Service unavailable: No GOOGLE_TTS_API_KEY or GOOGLE_APPLICATION_CREDENTIALS configured. ' +
                'Note: GEMINI_API_KEY is for Gemini AI, not Google Cloud TTS.';
            logger.warn(this.initError);
        }
    }

    /**
     * Check if TTS service is available
     */
    get available(): boolean {
        return this.isAvailable;
    }

    /**
     * Synthesize text to speech audio
     * @param text The text to convert to speech
     * @returns Base64 encoded MP3 audio
     * @throws Error if TTS is unavailable or synthesis fails
     */
    async synthesize(text: string): Promise<string> {
        if (!this.client || !this.isAvailable) {
            throw new Error(this.initError || 'TTS Service not initialized');
        }

        const request = {
            input: { text },
            voice: {
                languageCode: 'en-US',
                name: 'en-US-Chirp3-HD-Gacrux',
            },
            audioConfig: {
                audioEncoding: 'MP3' as const,
                sampleRateHertz: 44100,
                speakingRate: 1.25,
                volumeGainDb: 0.0,
            },
        };

        const [response] = await this.client.synthesizeSpeech(request);

        if (!response.audioContent) {
            throw new Error('No audio content returned from Google TTS');
        }

        return Buffer.from(response.audioContent as Uint8Array).toString('base64');
    }
}

export const ttsService = new TTSService();
