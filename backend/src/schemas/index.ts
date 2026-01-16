import { z } from 'zod';

// ==================================
// Core Data Schemas
// ==================================

// Ingredient Schema
const IngredientSchema = z.object({
    name: z.string().min(1, 'Ingredient name required'),
    amount: z.string().optional(),
    unit: z.string().optional(),
    notes: z.string().optional()
});

// Instruction Schema
const InstructionSchema = z.object({
    step: z.number().int().positive(),
    text: z.string().min(1, 'Instruction text required'),
    duration: z.number().optional(),
    temperature: z.string().optional()
});

// Recipe Schema (for validation)
const RecipeSchema = z.object({
    title: z.string().min(1).max(200),
    description: z.string().min(1).max(1000),
    ingredients: z.array(IngredientSchema).min(1, 'At least one ingredient required'),
    instructions: z.array(InstructionSchema).min(1, 'At least one instruction required'),
    difficulty: z.enum(['easy', 'medium', 'hard']).optional(),
    cookingTime: z.number().int().positive().optional(),
    step0Summary: z.string().optional(),
    step0AudioUrl: z.string().url().optional()
});

// Chat Message Schema
const ChatMessageSchema = z.object({
    role: z.enum(['user', 'assistant', 'system']),
    content: z.string().min(1)
});

// ==================================
// Route Schemas
// ==================================

export const ProcessRecipeSchema = z.object({
    body: z.object({
        url: z.string().url('Invalid URL format')
    })
});

export const ToggleFavoriteSchema = z.object({
    params: z.object({
        id: z.string().uuid('Invalid Recipe ID')
    }),
    body: z.object({
        isFavorite: z.boolean()
    })
});

export const RegisterDeviceSchema = z.object({
    body: z.object({
        deviceToken: z.string().min(1, 'Device token is required'),
        platform: z.enum(['ios', 'android'])
    })
});

export const GetPreferencesSchema = z.object({
    params: z.object({
        userId: z.string().uuid('Invalid User ID')
    })
});

// AI Schemas
export const GenerateRecipeSchema = z.object({
    body: z.object({
        userPrompt: z.string().min(3, 'Prompt too short')
    })
});

// Keep backward compatibility with .passthrough() while adding validation
export const RemixRecipeSchema = z.object({
    body: z.object({
        originalRecipe: RecipeSchema.passthrough(),  // Strict validation but allows extra fields
        userPrompt: z.string().min(1, 'Prompt required')
    })
});

export const RemixChatSchema = z.object({
    body: z.object({
        originalRecipe: RecipeSchema.passthrough(),
        chatHistory: z.array(ChatMessageSchema),
        userPrompt: z.string().min(1, 'Prompt required')
    })
});

export const ChatCompanionSchema = z.object({
    body: z.object({
        recipe: RecipeSchema.passthrough(),
        currentStepIndex: z.number().int().min(0, 'Step index must be non-negative'),
        chatHistory: z.array(ChatMessageSchema),
        userMessage: z.string().min(1, 'Message required').max(500, 'Message too long')
    })
});

export const PrepareStepSchema = z.object({
    body: z.object({
        recipe: RecipeSchema.passthrough(),
        stepIndex: z.number().int().min(0, 'Step index must be non-negative'),
        stepLabel: z.string().optional()
    })
});

export const TranscribeAudioSchema = z.object({
    body: z.object({
        audioBase64: z.string().min(1, 'Audio data required'),
        mimeType: z.string().optional().default('audio/webm')
    })
});

export const SynthesizeSchema = z.object({
    body: z.object({
        text: z.string().min(1, 'Text required').max(5000, 'Text too long for synthesis')
    })
});

// Recipe Version Schema (for saveVersion endpoint)
export const SaveVersionSchema = z.object({
    params: z.object({
        recipeId: z.string().uuid('Invalid recipe ID')
    }),
    body: z.object({
        title: z.string().min(1).max(200, 'Title too long'),
        description: z.string().min(1).max(1000, 'Description too long'),
        ingredients: z.array(IngredientSchema).min(1, 'At least one ingredient required'),
        instructions: z.array(InstructionSchema).min(1, 'At least one instruction required'),
        chefsNote: z.string().max(500, 'Chef note too long').optional(),
        changedIngredients: z.array(z.string()).optional().default([]),
        step0Summary: z.string().max(500).optional(),
        step0AudioUrl: z.string().url().optional(),
        difficulty: z.enum(['easy', 'medium', 'hard']).optional(),
        cookingTime: z.number().int().positive().optional()
    })
});
