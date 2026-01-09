
import WebSocket from 'ws';
import { IncomingMessage } from 'http';
import { supabase } from '../db/supabase';

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const GEMINI_WEBSOCKET_URL = `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=${GEMINI_API_KEY}`;

export class GeminiLiveService {

    constructor() { }

    /**
     * Handle a new WebSocket connection from the client.
     */
    async handleConnection(ws: WebSocket, req: IncomingMessage) {
        console.log("New Live Mode connection initiated");

        // 1. Parse Query Params for Context (Recipe ID, User ID)
        // expected url: /ws/live-cooking?recipeId=123&stepIndex=2
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

            // Send Initial Application Config (System Instruction)
            // We use the "tool_use" or "setup" message format
            const setupMessage = {
                setup: {
                    model: "models/gemini-2.0-flash-exp", // Verify model name availability
                    tools: [
                        {
                            function_declarations: [
                                {
                                    name: "get_step_instructions",
                                    description: "Get the full text instructions for a specific step index.",
                                    parameters: {
                                        type: "OBJECT",
                                        properties: {
                                            step_index: { type: "INTEGER" }
                                        },
                                        required: ["step_index"]
                                    }
                                }
                            ]
                        }
                    ],
                    system_instructions: {
                        parts: [
                            { text: "You are a friendly, helpful, and concise professional Sous Chef named 'Chef'." },
                            { text: "The user is currently cooking so keep your hands-free via voice interaction." },
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
        });

        geminiWs.on('message', (data: WebSocket.Data) => {
            // Forward Gemini -> Client
            // Gemini sends JSON or Binary blobs. We can just pipe them? 
            // Better to parse if possible to log, but raw piping is faster for audio.
            // But we might need to inspect for tool calls.

            // For now, simple relay of text/audio data
            if (ws.readyState === WebSocket.OPEN) {
                ws.send(data);
            }
        });

        geminiWs.on('close', () => {
            console.log("Gemini connection closed");
            if (ws.readyState === WebSocket.OPEN) ws.close();
        });

        geminiWs.on('error', (err) => {
            console.error("Gemini WebSocket error:", err);
            ws.close(1011, "Upstream error");
        });

        // 5. Setup Client -> Gemini Logic
        ws.on('message', (data: WebSocket.Data) => {
            // Forward Client -> Gemini
            if (geminiWs.readyState === WebSocket.OPEN) {
                geminiWs.send(data);
            }
        });

        ws.on('close', () => {
            console.log("Client connection closed");
            if (geminiWs.readyState === WebSocket.OPEN) geminiWs.close();
        });
    }
}
