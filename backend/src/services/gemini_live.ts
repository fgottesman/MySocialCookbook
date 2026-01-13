import WebSocket from 'ws';
import { IncomingMessage } from 'http';
import { User, SupabaseClient } from '@supabase/supabase-js';
import { AI_MODELS, VOICE_CONFIG } from '../config/ai_models';
import logger from '../utils/logger';

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
// Base URL without the key in query params
const GEMINI_WEBSOCKET_URL = `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent`;

export class GeminiLiveService {
    constructor() {
        logger.info("[GeminiLive] Service initialized");
        logger.info(`[GeminiLive] API Key present: ${!!GEMINI_API_KEY}`);
        logger.info(`[GeminiLive] API Key length: ${GEMINI_API_KEY?.length || 0}`);
    }
    async handleConnection(ws: WebSocket, req: IncomingMessage, user: User, userSupabase: SupabaseClient) {
        logger.info(`[GeminiLive] ======= NEW CONNECTION: ${user.email} =======`);

        // 1. Parse Query Params
        const url = new URL(req.url || '', `http://${req.headers.host}`);
        const recipeId = url.searchParams.get('recipeId');
        const versionId = url.searchParams.get('versionId');
        const stepIndex = parseInt(url.searchParams.get('stepIndex') || '0');

        logger.info(`[GeminiLive] Recipe ID: ${recipeId}`);
        logger.info(`[GeminiLive] Version ID: ${versionId}`);
        logger.info(`[GeminiLive] Step Index: ${stepIndex}`);

        // Generic UUID validation (handles v1, v4, v7 etc)
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        if (!recipeId || !uuidRegex.test(recipeId)) {
            logger.error("[GeminiLive] ❌ Invalid or missing recipeId");
            ws.close(1008, "Invalid or missing recipeId");
            return;
        }

        // Check API key
        if (!GEMINI_API_KEY) {
            logger.error("[GeminiLive] ❌ GEMINI_API_KEY not set!");
            ws.close(1011, "Server configuration error");
            return;
        }

        // 2. Fetch Recipe Context
        logger.info("[GeminiLive] Fetching recipe from database...");

        let recipe;
        let error;

        if (versionId) {
            // Fetch specific version
            logger.info("[GeminiLive] Fetching remixed version...");
            const { data, error: err } = await userSupabase
                .from('recipe_versions')
                .select('*')
                .eq('id', versionId)
                .single();

            error = err;
            if (data) {
                // Security/Logic check: Warning if provided recipeId doesn't match version's parent
                if (data.recipe_id !== recipeId) {
                    logger.warn(`[GeminiLive] ⚠️ ID Mismatch: Version ${versionId} belongs to recipe ${data.recipe_id}, but request specified ${recipeId}. Proceeding with version's actual parent.`);
                }

                // Map version data to standard recipe structure if needed
                recipe = {
                    ...data,
                    // Ensure we have the base fields the AI expects
                    title: data.title,
                    ingredients: data.ingredients,
                    instructions: data.instructions || []
                };
            }
        } else {
            // Fetch original
            logger.info("[GeminiLive] Fetching original recipe...");
            const { data, error: err } = await userSupabase
                .from('recipes')
                .select('*')
                .eq('id', recipeId)
                .single();
            recipe = data;
            error = err;
        }

        if (error || !recipe) {
            logger.error(`[GeminiLive] ❌ Recipe not found: ${error?.message}`);
            ws.close(1008, "Recipe not found");
            return;
        }

        logger.info(`[GeminiLive] ✅ Recipe found: ${recipe.title}`);

        // 3. Connect to Gemini Live
        logger.info("[GeminiLive] Connecting to Gemini Live API...");

        let geminiWs: WebSocket;
        try {
            // Using x-goog-api-key header for maximum security. 
            // If this fails, we do NOT fall back to query params as they are insecure.
            geminiWs = new WebSocket(GEMINI_WEBSOCKET_URL, {
                headers: {
                    'x-goog-api-key': GEMINI_API_KEY || ''
                }
            });
            console.log("[GeminiLive] ✅ Initialized WebSocket with header auth");
        } catch (e) {
            console.error("[GeminiLive] ❌ WebSocket initialization failed:", e);
            ws.close(1011, "Internal server error connecting to AI");
            return;
        }

        geminiWs.on('open', () => {
            console.log("[GeminiLive] ✅ Connected to Gemini Live API!");

            const setupMessage = {
                setup: {
                    model: `models/${AI_MODELS.VOICE_LIVE}`,
                    generationConfig: {
                        responseModalities: ["AUDIO"],
                        speechConfig: {
                            voiceConfig: {
                                prebuiltVoiceConfig: {
                                    voiceName: VOICE_CONFIG.DEFAULT_VOICE
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
            try {
                const dataStr = data.toString();
                const response = JSON.parse(dataStr);

                // Check for audio data in the response
                if (response.serverContent?.modelTurn?.parts) {
                    for (const part of response.serverContent.modelTurn.parts) {
                        if (part.inlineData?.mimeType?.startsWith('audio/')) {
                            // Decode base64 audio and send as raw binary to client
                            const audioData = Buffer.from(part.inlineData.data, 'base64');
                            console.log("[GeminiLive] 🔊 Sending audio to client:", audioData.length, "bytes");
                            if (ws.readyState === WebSocket.OPEN) {
                                ws.send(audioData);
                            }
                        } else if (part.text) {
                            // Text response - send as JSON
                            console.log("[GeminiLive] 💬 Text response:", part.text.substring(0, 100));
                            if (ws.readyState === WebSocket.OPEN) {
                                ws.send(JSON.stringify({ type: 'text', text: part.text }));
                            }
                        }
                    }
                }

                // Handle setup complete
                if (response.setupComplete) {
                    console.log("[GeminiLive] ✅ Setup complete acknowledged by Gemini");

                    // Proactive Welcome Message
                    const welcomeMessage = {
                        client_content: {
                            turns: [
                                {
                                    role: "user",
                                    parts: [{ text: "Say exactly: 'Hey chef, how can I help you with this recipe today?'" }]
                                }
                            ],
                            turn_complete: true
                        }
                    };

                    console.log("[GeminiLive] 🗣️ Sending welcome prompt to AI");
                    geminiWs.send(JSON.stringify(welcomeMessage));
                }

                // Handle turn complete
                if (response.serverContent?.turnComplete) {
                    console.log("[GeminiLive] ✅ Turn complete");
                }

            } catch (e) {
                // If not valid JSON, it might be raw binary audio (shouldn't happen but handle gracefully)
                console.log("[GeminiLive] ⚠️ Non-JSON message received, forwarding as-is");
                try {
                    if (ws.readyState === WebSocket.OPEN) {
                        ws.send(data);
                    }
                } catch (sendError) {
                    console.error("[GeminiLive] ❌ Failed to forward binary data:", sendError);
                }
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
                                mimeType: VOICE_CONFIG.MIME_TYPE,
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

        // 6. Heartbeat / Keep-alive
        const heartbeatInterval = setInterval(() => {
            if (ws.readyState === WebSocket.OPEN) {
                ws.ping();
            } else {
                clearInterval(heartbeatInterval);
            }
        }, 30000); // 30 seconds

        ws.on('close', (code, reason) => {
            clearInterval(heartbeatInterval);
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
