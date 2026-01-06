import { TextToSpeechClient } from '@google-cloud/text-to-speech';

export class TTSService {
    private client: TextToSpeechClient;

    constructor() {
        this.client = new TextToSpeechClient({
            apiKey: process.env.GEMINI_API_KEY
        });
    }

    async synthesize(text: string): Promise<string> {
        const request = {
            input: { text },
            // Select the language and SSML voice gender (optional)
            voice: {
                languageCode: 'en-US',
                name: 'en-US-Chirp3-HD-Gacrux',
            },
            // select the type of audio encoding
            audioConfig: {
                audioEncoding: 'LINEAR16' as const,
                sampleRateHertz: 44100,
                speakingRate: 1.25,
                volumeGainDb: 0.0,
            },
        };

        // Performs the text-to-speech request
        const [response] = await this.client.synthesizeSpeech(request);

        if (!response.audioContent) {
            throw new Error('No audio content returned from Google TTS');
        }

        // Convert the binary audio content to a base64 string
        const audioBase64 = Buffer.from(response.audioContent as Uint8Array).toString('base64');
        return audioBase64;
    }
}

export const ttsService = new TTSService();
