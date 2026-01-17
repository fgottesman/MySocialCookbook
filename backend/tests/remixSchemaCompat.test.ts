/**
 * Schema Compatibility Tests for Remix Flow
 *
 * These tests ensure that server-side validation schemas accept
 * the actual payload formats sent by the iOS client.
 *
 * IMPORTANT: If these tests fail, it means a schema change broke
 * compatibility with the iOS client. Fix the schema, NOT the tests.
 *
 * Run with: npm test
 */

import {
    RemixChatSchema,
    RemixRecipeSchema,
    SaveVersionSchema,
    ChatCompanionSchema,
    PrepareStepSchema
} from '../src/schemas';

describe('Remix Flow Schema Compatibility', () => {
    // Simulates the actual payload format sent by iOS client
    // Instructions are strings (not objects), difficulty may be capitalized
    const iosClientRecipe = {
        id: '8B04FBCE-60B0-43E4-9D6D-01FA50FFE3FD',
        userId: '123e4567-e89b-12d3-a456-426614174000',
        title: 'Classic Pasta Carbonara',
        description: 'A traditional Italian pasta dish',
        ingredients: [
            'spaghetti',
            '4 eggs',
            '200g pancetta',
            '100g pecorino romano'
        ],
        // iOS sends instructions as plain strings, NOT objects
        instructions: [
            'Boil water and cook pasta',
            'Fry the pancetta until crispy',
            'Mix eggs with cheese',
            'Combine pasta with pancetta',
            'Add egg mixture off heat',
            'Toss until creamy',
            'Serve immediately'
        ],
        // iOS may send difficulty in various cases
        difficulty: 'Medium',
        // iOS may send cookingTime as string
        cookingTime: '30 minutes',
        step0Summary: 'Welcome to Classic Pasta Carbonara!',
        step0AudioUrl: 'https://example.com/audio.mp3'
    };

    const iosClientRecipeWithObjects = {
        ...iosClientRecipe,
        ingredients: [
            { name: 'spaghetti', amount: '400', unit: 'g' },
            { name: 'eggs', amount: '4', unit: '' }
        ],
        instructions: [
            { step: 1, text: 'Boil water and cook pasta' },
            { step: 2, text: 'Fry the pancetta until crispy' }
        ],
        difficulty: 'easy',
        cookingTime: 30
    };

    describe('RemixChatSchema', () => {
        it('accepts iOS client payload with string instructions', () => {
            const payload = {
                body: {
                    originalRecipe: iosClientRecipe,
                    chatHistory: [
                        { role: 'user', content: 'Make it spicier' },
                        { role: 'assistant', content: 'I can add red pepper flakes' }
                    ],
                    userPrompt: 'Yes, please add the red pepper flakes'
                }
            };

            expect(() => RemixChatSchema.parse(payload)).not.toThrow();
        });

        it('accepts payload with object instructions', () => {
            const payload = {
                body: {
                    originalRecipe: iosClientRecipeWithObjects,
                    chatHistory: [],
                    userPrompt: 'Make it vegetarian'
                }
            };

            expect(() => RemixChatSchema.parse(payload)).not.toThrow();
        });

        it('accepts various difficulty cases', () => {
            const cases = ['easy', 'Easy', 'EASY', 'medium', 'Medium', 'hard', 'Hard'];

            cases.forEach((difficulty) => {
                const payload = {
                    body: {
                        originalRecipe: { ...iosClientRecipe, difficulty },
                        chatHistory: [],
                        userPrompt: 'Test'
                    }
                };

                expect(() => RemixChatSchema.parse(payload)).not.toThrow();
            });
        });
    });

    describe('RemixRecipeSchema', () => {
        it('accepts iOS client payload format', () => {
            const payload = {
                body: {
                    originalRecipe: iosClientRecipe,
                    userPrompt: 'Make it gluten-free'
                }
            };

            expect(() => RemixRecipeSchema.parse(payload)).not.toThrow();
        });
    });

    describe('SaveVersionSchema', () => {
        it('accepts iOS client payload with string instructions', () => {
            const payload = {
                params: {
                    recipeId: '8B04FBCE-60B0-43E4-9D6D-01FA50FFE3FD'
                },
                body: {
                    title: 'Spicy Pasta Carbonara',
                    description: 'A spicy twist on the classic',
                    ingredients: ['spaghetti', 'eggs', 'pancetta', 'red pepper flakes'],
                    instructions: [
                        'Boil water and cook pasta',
                        'Fry pancetta with red pepper',
                        'Mix eggs with cheese',
                        'Combine and serve'
                    ],
                    difficulty: 'Medium',
                    cookingTime: '35 minutes',
                    chefsNote: 'Added extra heat!'
                }
            };

            expect(() => SaveVersionSchema.parse(payload)).not.toThrow();
        });

        it('accepts payload with object instructions', () => {
            const payload = {
                params: {
                    recipeId: '8B04FBCE-60B0-43E4-9D6D-01FA50FFE3FD'
                },
                body: {
                    title: 'Spicy Pasta Carbonara',
                    ingredients: [{ name: 'spaghetti', amount: '400', unit: 'g' }],
                    instructions: [{ step: 1, text: 'Boil water' }],
                    difficulty: 'easy',
                    cookingTime: 35
                }
            };

            expect(() => SaveVersionSchema.parse(payload)).not.toThrow();
        });

        it('accepts cookingTime as string or number', () => {
            const basePayload = {
                params: { recipeId: '8B04FBCE-60B0-43E4-9D6D-01FA50FFE3FD' },
                body: {
                    title: 'Test Recipe',
                    ingredients: ['ingredient'],
                    instructions: ['step 1']
                }
            };

            // String format
            expect(() => SaveVersionSchema.parse({
                ...basePayload,
                body: { ...basePayload.body, cookingTime: '30-45 minutes' }
            })).not.toThrow();

            // Number format
            expect(() => SaveVersionSchema.parse({
                ...basePayload,
                body: { ...basePayload.body, cookingTime: 30 }
            })).not.toThrow();
        });
    });

    describe('ChatCompanionSchema', () => {
        it('accepts iOS client recipe format', () => {
            const payload = {
                body: {
                    recipe: iosClientRecipe,
                    currentStepIndex: 2,
                    chatHistory: [
                        { role: 'user', content: 'How long should I fry the pancetta?' }
                    ],
                    userMessage: 'Is it ready when golden?'
                }
            };

            expect(() => ChatCompanionSchema.parse(payload)).not.toThrow();
        });
    });

    describe('PrepareStepSchema', () => {
        it('accepts iOS client recipe format', () => {
            const payload = {
                body: {
                    recipe: iosClientRecipe,
                    stepIndex: 0,
                    stepLabel: 'Getting Started'
                }
            };

            expect(() => PrepareStepSchema.parse(payload)).not.toThrow();
        });
    });

    describe('Edge Cases', () => {
        it('handles empty optional fields', () => {
            const minimalRecipe = {
                title: 'Test Recipe',
                instructions: ['Do something']
            };

            const payload = {
                body: {
                    originalRecipe: minimalRecipe,
                    chatHistory: [],
                    userPrompt: 'Test'
                }
            };

            expect(() => RemixChatSchema.parse(payload)).not.toThrow();
        });

        it('handles mixed instruction formats in same array', () => {
            const mixedRecipe = {
                title: 'Test Recipe',
                instructions: [
                    'Plain string instruction',
                    { step: 2, text: 'Object instruction' },
                    'Another string'
                ]
            };

            const payload = {
                body: {
                    originalRecipe: mixedRecipe,
                    chatHistory: [],
                    userPrompt: 'Test'
                }
            };

            expect(() => RemixChatSchema.parse(payload)).not.toThrow();
        });

        it('handles null/undefined difficulty gracefully', () => {
            const recipeWithNoDifficulty = {
                title: 'Test Recipe',
                instructions: ['Step 1']
            };

            const payload = {
                body: {
                    originalRecipe: recipeWithNoDifficulty,
                    chatHistory: [],
                    userPrompt: 'Test'
                }
            };

            expect(() => RemixChatSchema.parse(payload)).not.toThrow();
        });
    });
});
