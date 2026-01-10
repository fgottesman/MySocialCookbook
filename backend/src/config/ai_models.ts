
/**
 * AI Model Configuration for ClipCook
 * Centralized list of models to avoid hardcoding across the codebase.
 * Updated: January 2026
 */

export const AI_MODELS = {
    // Primary recipe extraction and generation (Multimodal)
    RECIPE_ENGINE: "gemini-3-flash-preview",

    // Real-time voice interaction
    VOICE_LIVE: "gemini-2.5-flash-native-audio-preview",

    // High-quality text tasks
    TEXT_PRO: "gemini-2.5-pro",

    // Embeddings
    EMBEDDING: "text-embedding-004",

    // Image Generation
    IMAGE_GEN: "gemini-2.5-flash-preview-native-image"
};

export const VOICE_CONFIG = {
    DEFAULT_VOICE: "Gacrux", // Female voice for gemini-2.5-flash-native-audio
    SAMPLE_RATE: 16000,
    MIME_TYPE: "audio/pcm;rate=16000"
};
