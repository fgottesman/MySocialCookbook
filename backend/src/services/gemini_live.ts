
import WebSocket from 'ws';
import { IncomingMessage } from 'http';
import { supabase } from '../db/supabase';

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
// Use v1beta endpoint (the correct one for Live API)
const GEMINI_WEBSOCKET_URL = `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=${GEMINI_API_KEY}`;

export class GeminiLiveService {

    constructor() { }

    /**
     * Handle a new WebSocket connection from the client.
     */
    async handleConnection(ws: WebSocket, req: IncomingMessage) {
        console.log("New Live Mode connection initiated");

        // 1. Parse Query Params for Context (Recipe ID, User ID)
        const url = new URL(req.url || '', `http://${req.headers.host}`);
        const recipeId = url.searchParams.get('recipeId');
        const stepIndex = parseInt(url.searchParams.get('stepIndex') || '0');

        if (!recipeId) {
            console.error("Missing recipeId for Live Session");
            ws.close(1008, "Missing recipeId");
            return;
        }

        // 2. Fetch Recipe Context
        const { data: recipe, error } = await supabase
            .from('recipes')
            .select('*')
            .eq('id', recipeId)
            .single();

        if (error || !recipe) {
            console.error("Recipe not found", error);
            ws.close(1008, "Recipe not found");
            return;
        }

        console.log(`Starting Live Session for recipe: ${recipe.title}`);

        // 3. Connect to Gemini Live
        const geminiWs = new WebSocket(GEMINI_WEBSOCKET_URL);

        // 4. Setup Relay Logic
        geminiWs.on('open', () => {
            console.log("Connected to Gemini Live API");

            // Send Initial BidiGenerateContentSetup message (correct format per docs)
            const setupMessage = {
                setup: {
                    model: "models/gemini-2.0-flash-live-001",
                    generationConfig: {
                        responseModalities: ["AUDIO"],
                        speechConfig: {
                            voiceConfig: {
                                prebuiltVoiceConfig: {
                                    voiceName: "Puck"
                                }
                            }
                        }
                    },
                    systemInstruction: {
                        parts: [
                            { text: "You are a friendly, helpful, and concise professional Sous Chef named 'Chef'." },
                            { text: "The user is currently cooking so keep responses brief for hands-free voice interaction." },
                            { text: `You are guiding them through the recipe: "${recipe.title}".` },
                            { text: `Ingredients: ${JSON.stringify(recipe.ingredients)}` },
                            { text: `Instructions: ${JSON.stringify(recipe.instructions)}` },
                            { text: "Start by greeting them and asking if they are ready for the current step." },
                            { text: "If they ask for amounts, be precise. If they just chat, be friendly but brief." }
                        ]
                    }
                }
            };

            geminiWs.send(JSON.stringify(setupMessage));
            console.log("Sent setup message to Gemini");
        });

        geminiWs.on('message', (data: WebSocket.Data) => {
            // Forward Gemini -> Client
            if (ws.readyState === WebSocket.OPEN) {
                // Log first few chars for debugging
                if (typeof data === 'string') {
                    console.log("Gemini text response:", data.substring(0, 200));
                } else {
                    console.log("Gemini binary response:", (data as Buffer).length, "bytes");
                }
                ws.send(data);
            }
        });

        geminiWs.on('close', (code, reason) => {
            console.log("Gemini connection closed:", code, reason?.toString());
            if (ws.readyState === WebSocket.OPEN) ws.close();
        });

        geminiWs.on('error', (err) => {
            console.error("Gemini WebSocket error:", err.message);
            ws.close(1011, "Upstream error");
        });

        // 5. Setup Client -> Gemini Logic
        ws.on('message', (data: WebSocket.Data) => {
            // Forward Client -> Gemini
            // Client sends raw audio bytes, we wrap them in realtimeInput format
            if (geminiWs.readyState === WebSocket.OPEN) {
                if (Buffer.isBuffer(data)) {
                    // Wrap audio in the correct format
                    const audioMessage = {
                        realtimeInput: {
                            mediaChunks: [{
                                mimeType: "audio/pcm;rate=16000",
                                data: data.toString('base64')
                            }]
                        }
                    };
                    geminiWs.send(JSON.stringify(audioMessage));
                } else {
                    // Text/JSON messages pass through
                    geminiWs.send(data);
                }
            }
        });

        ws.on('close', () => {
            console.log("Client connection closed");
            if (geminiWs.readyState === WebSocket.OPEN) geminiWs.close();
        });
    }
}
