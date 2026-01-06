import { TextToSpeechClient } from '@google-cloud/text-to-speech';

export class TTSService {
    private client: TextToSpeechClient;

    constructor() {
        this.client = new TextToSpeechClient();
    }

    async synthesize(text: string): Promise<string> {
        const request = {
            input: { text },
            // Select the language and SSML voice gender (optional)
            voice: {
                languageCode: 'en-US',
                name: 'en-US-Journey-F', // This is a high-quality "Gemini" like voice
            },
            // select the type of audio encoding
            audioConfig: { audioEncoding: 'MP3' as const },
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
