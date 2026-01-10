
import WebSocket from 'ws';
import { IncomingMessage } from 'http';
import { supabase } from '../db/supabase';

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
// Use v1beta endpoint (the correct one for Live API)
const GEMINI_WEBSOCKET_URL = `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=${GEMINI_API_KEY}`;

export class GeminiLiveService {
    constructor() {
        console.log("[GeminiLive] Service initialized");
        console.log("[GeminiLive] API Key present:", !!GEMINI_API_KEY);
        console.log("[GeminiLive] API Key length:", GEMINI_API_KEY?.length || 0);
    }

    async handleConnection(ws: WebSocket, req: IncomingMessage) {
        console.log("[GeminiLive] ======= NEW CONNECTION =======");

        // 1. Parse Query Params
        const url = new URL(req.url || '', `http://${req.headers.host}`);
        const recipeId = url.searchParams.get('recipeId');
        const stepIndex = parseInt(url.searchParams.get('stepIndex') || '0');

        console.log("[GeminiLive] Recipe ID:", recipeId);
        console.log("[GeminiLive] Step Index:", stepIndex);

        if (!recipeId) {
            console.error("[GeminiLive] ❌ Missing recipeId");
            ws.close(1008, "Missing recipeId");
            return;
        }

        // Check API key
        if (!GEMINI_API_KEY) {
            console.error("[GeminiLive] ❌ GEMINI_API_KEY not set!");
            ws.close(1011, "Server configuration error");
            return;
        }

        // 2. Fetch Recipe Context
        console.log("[GeminiLive] Fetching recipe from database...");
        const { data: recipe, error } = await supabase
            .from('recipes')
            .select('*')
            .eq('id', recipeId)
            .single();

        if (error || !recipe) {
            console.error("[GeminiLive] ❌ Recipe not found:", error?.message);
            ws.close(1008, "Recipe not found");
            return;
        }

        console.log("[GeminiLive] ✅ Recipe found:", recipe.title);

        // 3. Connect to Gemini Live
        console.log("[GeminiLive] Connecting to Gemini Live API...");
        console.log("[GeminiLive] URL:", GEMINI_WEBSOCKET_URL.replace(GEMINI_API_KEY || '', '[REDACTED]'));

        const geminiWs = new WebSocket(GEMINI_WEBSOCKET_URL);

        geminiWs.on('open', () => {
            console.log("[GeminiLive] ✅ Connected to Gemini Live API!");

            const setupMessage = {
                setup: {
                    model: "models/gemini-live-2.5-flash-native-audio",
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
                            { text: "You are a friendly, helpful Sous Chef named 'Chef'. Keep responses brief." },
                            { text: `Recipe: "${recipe.title}"` },
                            { text: `Ingredients: ${JSON.stringify(recipe.ingredients?.slice(0, 10))}` },
                            { text: "Greet the user and ask if they're ready." }
                        ]
                    }
                }
            };

            console.log("[GeminiLive] Sending setup message...");
            geminiWs.send(JSON.stringify(setupMessage));
            console.log("[GeminiLive] ✅ Setup message sent");
        });

        geminiWs.on('message', (data: WebSocket.Data) => {
            const dataStr = data.toString();
            if (dataStr.length < 500) {
                console.log("[GeminiLive] 📥 Gemini message:", dataStr);
            } else {
                console.log("[GeminiLive] 📥 Gemini binary data:", (data as Buffer).length, "bytes");
            }

            if (ws.readyState === WebSocket.OPEN) {
                ws.send(data);
            }
        });

        geminiWs.on('close', (code, reason) => {
            console.log("[GeminiLive] ⚠️ Gemini connection closed");
            console.log("[GeminiLive] Close code:", code);
            console.log("[GeminiLive] Close reason:", reason?.toString() || "none");
            if (ws.readyState === WebSocket.OPEN) {
                ws.close(code, reason?.toString());
            }
        });

        geminiWs.on('error', (err) => {
            console.error("[GeminiLive] ❌ Gemini WebSocket error:", err.message);
            console.error("[GeminiLive] Error details:", err);
            ws.close(1011, "Upstream error: " + err.message);
        });

        // 5. Client -> Gemini
        ws.on('message', (data: WebSocket.Data) => {
            if (geminiWs.readyState === WebSocket.OPEN) {
                if (Buffer.isBuffer(data)) {
                    // Wrap audio in correct format for Gemini
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
                    geminiWs.send(data);
                }
            } else {
                console.log("[GeminiLive] ⚠️ Cannot send to Gemini - not connected. State:", geminiWs.readyState);
            }
        });

        ws.on('close', (code, reason) => {
            console.log("[GeminiLive] Client disconnected. Code:", code);
            if (geminiWs.readyState === WebSocket.OPEN) {
                geminiWs.close();
            }
        });

        ws.on('error', (err) => {
            console.error("[GeminiLive] Client WebSocket error:", err.message);
        });
    }
}
