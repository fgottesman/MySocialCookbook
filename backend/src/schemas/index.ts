import { z } from 'zod';

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

export const RemixRecipeSchema = z.object({
    body: z.object({
        originalRecipe: z.record(z.string(), z.any()),
        userPrompt: z.string().min(1)
    })
});

export const RemixChatSchema = z.object({
    body: z.object({
        originalRecipe: z.record(z.string(), z.any()),
        chatHistory: z.array(z.any()),
        userPrompt: z.string().min(1)
    })
});

export const ChatCompanionSchema = z.object({
    body: z.object({
        recipe: z.record(z.string(), z.any()),
        currentStepIndex: z.number().int().min(0),
        chatHistory: z.array(z.any()),
        userMessage: z.string().min(1)
    })
});

export const PrepareStepSchema = z.object({
    body: z.object({
        recipe: z.record(z.string(), z.any()),
        stepIndex: z.number().int().min(0)
    })
});

export const TranscribeAudioSchema = z.object({
    body: z.object({
        audio: z.string().min(1, 'Audio data required'),
        mimeType: z.string().optional()
    })
});

export const SynthesizeSchema = z.object({
    body: z.object({
        text: z.string().min(1, 'Text required')
    })
});
