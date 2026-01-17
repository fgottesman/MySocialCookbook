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

// Instruction Schema (strict - for new recipes)
const InstructionSchema = z.object({
    step: z.number().int().positive(),
    text: z.string().min(1, 'Instruction text required'),
    duration: z.number().optional(),
    temperature: z.string().optional()
});

// Flexible Instruction Schema - accepts both string and object formats
// This handles legacy iOS clients that send instructions as string[]
const FlexibleInstructionSchema = z.union([
    z.string().min(1),
    InstructionSchema
]);

// Normalize difficulty to lowercase enum value
const FlexibleDifficultySchema = z.preprocess(
    (val) => {
        if (typeof val === 'string') {
            const lower = val.toLowerCase();
            if (['easy', 'medium', 'hard'].includes(lower)) {
                return lower;
            }
        }
        return val;
    },
    z.enum(['easy', 'medium', 'hard']).optional()
);

// Recipe Schema (strict - for validation of new recipes)
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

// Flexible Recipe Schema - for remix endpoints that need to accept existing client data
// Handles iOS clients that may send instructions as strings and difficulty in various cases
const FlexibleRecipeSchema = z.object({
    title: z.string().min(1).max(200),
    description: z.string().max(1000).optional(),
    ingredients: z.array(z.union([IngredientSchema, z.string()])).optional(),
    instructions: z.array(FlexibleInstructionSchema).min(1, 'At least one instruction required'),
    difficulty: FlexibleDifficultySchema,
    cookingTime: z.union([z.number().int().positive(), z.string()]).optional(),
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

// Use flexible schema for remix endpoints to handle legacy iOS client formats
// (instructions as strings, difficulty in various cases, etc.)
export const RemixRecipeSchema = z.object({
    body: z.object({
        originalRecipe: FlexibleRecipeSchema.passthrough(),
        userPrompt: z.string().min(1, 'Prompt required')
    })
});

export const RemixChatSchema = z.object({
    body: z.object({
        originalRecipe: FlexibleRecipeSchema.passthrough(),
        chatHistory: z.array(ChatMessageSchema),
        userPrompt: z.string().min(1, 'Prompt required')
    })
});

// Use flexible schema for endpoints receiving recipe data from iOS client
export const ChatCompanionSchema = z.object({
    body: z.object({
        recipe: FlexibleRecipeSchema.passthrough(),
        currentStepIndex: z.number().int().min(0, 'Step index must be non-negative'),
        chatHistory: z.array(ChatMessageSchema),
        userMessage: z.string().min(1, 'Message required').max(500, 'Message too long')
    })
});

export const PrepareStepSchema = z.object({
    body: z.object({
        recipe: FlexibleRecipeSchema.passthrough(),
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
