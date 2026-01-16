/**
 * Tests for Recipe Versioning
 * Validates the race condition fix for concurrent version creation
 */

import { Request, Response } from 'express';
import { RecipeController } from '../src/controllers/RecipeController';

describe('Recipe Versioning', () => {
    let mockReq: Partial<Request>;
    let mockRes: Partial<Response>;
    let mockSupabase: any;

    beforeEach(() => {
        mockSupabase = {
            from: jest.fn(),
            storage: {
                from: jest.fn()
            }
        };

        mockReq = {
            params: { recipeId: 'recipe-123' },
            body: {
                title: 'Remixed Recipe',
                description: 'A delicious remix',
                ingredients: [{ name: 'Flour', amount: '2 cups' }],
                instructions: [{ step: 1, text: 'Mix ingredients' }],
                chefsNote: 'Made it spicier',
                changedIngredients: ['Added chili'],
                step0Summary: 'Prep ingredients',
                step0AudioUrl: 'https://example.com/audio.mp3',
                difficulty: 'medium',
                cookingTime: 30
            },
            supabase: mockSupabase,
            user: {
                id: 'user-123',
                app_metadata: {},
                user_metadata: {},
                aud: 'authenticated',
                created_at: new Date().toISOString()
            } as any
        };

        mockRes = {
            status: jest.fn().mockReturnThis(),
            json: jest.fn()
        };

        jest.clearAllMocks();
    });

    describe('saveVersion - Race Condition Handling', () => {
        it('should handle first remix by creating original snapshot', async () => {
            // First query: check for existing versions (none exist)
            mockSupabase.from.mockReturnValueOnce({
                select: jest.fn().mockReturnValue({
                    eq: jest.fn().mockReturnValue({
                        order: jest.fn().mockReturnValue({
                            limit: jest.fn().mockReturnValue({
                                single: jest.fn().mockResolvedValue({
                                    data: null,
                                    error: { code: 'PGRST116' } // No rows found
                                })
                            })
                        })
                    })
                })
            });

            // Second query: fetch original recipe
            mockSupabase.from.mockReturnValueOnce({
                select: jest.fn().mockReturnValue({
                    eq: jest.fn().mockReturnValue({
                        single: jest.fn().mockResolvedValue({
                            data: {
                                id: 'recipe-123',
                                title: 'Original Recipe',
                                description: 'The original',
                                ingredients: [{ name: 'Sugar', amount: '1 cup' }],
                                instructions: [{ step: 1, text: 'Combine' }],
                                chefs_note: null,
                                step0_summary: 'Get ready',
                                step0_audio_url: null,
                                difficulty: 'easy',
                                cooking_time: 20,
                                created_at: new Date().toISOString()
                            },
                            error: null
                        })
                    })
                })
            });

            // Third query: insert original as version 1
            mockSupabase.from.mockReturnValueOnce({
                insert: jest.fn().mockResolvedValue({ error: null })
            });

            // Fourth query: insert remix as version 2
            mockSupabase.from.mockReturnValueOnce({
                insert: jest.fn().mockReturnValue({
                    select: jest.fn().mockReturnValue({
                        single: jest.fn().mockResolvedValue({
                            data: {
                                id: 'version-2',
                                recipe_id: 'recipe-123',
                                version_number: 2,
                                ...mockReq.body
                            },
                            error: null
                        })
                    })
                })
            });

            await RecipeController.saveVersion(mockReq as any, mockRes as Response);

            expect(mockRes.json).toHaveBeenCalledWith({
                success: true,
                version: expect.objectContaining({
                    version_number: 2,
                    title: 'Remixed Recipe'
                })
            });
        });

        it('should handle subsequent remixes correctly', async () => {
            // Query: check existing versions (version 1 and 2 exist)
            mockSupabase.from.mockReturnValueOnce({
                select: jest.fn().mockReturnValue({
                    eq: jest.fn().mockReturnValue({
                        order: jest.fn().mockReturnValue({
                            limit: jest.fn().mockReturnValue({
                                single: jest.fn().mockResolvedValue({
                                    data: { version_number: 2 },
                                    error: null
                                })
                            })
                        })
                    })
                })
            });

            // Insert new version 3
            mockSupabase.from.mockReturnValueOnce({
                insert: jest.fn().mockReturnValue({
                    select: jest.fn().mockReturnValue({
                        single: jest.fn().mockResolvedValue({
                            data: {
                                id: 'version-3',
                                recipe_id: 'recipe-123',
                                version_number: 3,
                                ...mockReq.body
                            },
                            error: null
                        })
                    })
                })
            });

            await RecipeController.saveVersion(mockReq as any, mockRes as Response);

            expect(mockRes.json).toHaveBeenCalledWith({
                success: true,
                version: expect.objectContaining({
                    version_number: 3
                })
            });
        });

        it('should retry on duplicate key violation (race condition)', async () => {
            // First attempt: version 2 exists
            mockSupabase.from.mockReturnValueOnce({
                select: jest.fn().mockReturnValue({
                    eq: jest.fn().mockReturnValue({
                        order: jest.fn().mockReturnValue({
                            limit: jest.fn().mockReturnValue({
                                single: jest.fn().mockResolvedValue({
                                    data: { version_number: 2 },
                                    error: null
                                })
                            })
                        })
                    })
                })
            });

            // First insert fails with duplicate
            mockSupabase.from.mockReturnValueOnce({
                insert: jest.fn().mockReturnValue({
                    select: jest.fn().mockReturnValue({
                        single: jest.fn().mockResolvedValue({
                            data: null,
                            error: {
                                code: '23505',
                                message: 'duplicate key value violates unique constraint'
                            }
                        })
                    })
                })
            });

            // Second attempt: now version 3 exists (concurrent request created it)
            mockSupabase.from.mockReturnValueOnce({
                select: jest.fn().mockReturnValue({
                    eq: jest.fn().mockReturnValue({
                        order: jest.fn().mockReturnValue({
                            limit: jest.fn().mockReturnValue({
                                single: jest.fn().mockResolvedValue({
                                    data: { version_number: 3 },
                                    error: null
                                })
                            })
                        })
                    })
                })
            });

            // Second insert succeeds with version 4
            mockSupabase.from.mockReturnValueOnce({
                insert: jest.fn().mockReturnValue({
                    select: jest.fn().mockReturnValue({
                        single: jest.fn().mockResolvedValue({
                            data: {
                                id: 'version-4',
                                recipe_id: 'recipe-123',
                                version_number: 4,
                                ...mockReq.body
                            },
                            error: null
                        })
                    })
                })
            });

            // Mock setTimeout to execute immediately in tests
            jest.useFakeTimers();

            const savePromise = RecipeController.saveVersion(mockReq as any, mockRes as Response);

            // Fast-forward timers for async code
            await jest.advanceTimersByTimeAsync(1000);

            await savePromise;

            expect(mockRes.json).toHaveBeenCalledWith({
                success: true,
                version: expect.objectContaining({
                    version_number: 4
                })
            });

            jest.useRealTimers();
        });

        it('should fail after maximum retries', async () => {
            // All 3 attempts fail with duplicate error
            for (let i = 0; i < 3; i++) {
                // Query existing versions
                mockSupabase.from.mockReturnValueOnce({
                    select: jest.fn().mockReturnValue({
                        eq: jest.fn().mockReturnValue({
                            order: jest.fn().mockReturnValue({
                                limit: jest.fn().mockReturnValue({
                                    single: jest.fn().mockResolvedValue({
                                        data: { version_number: 2 },
                                        error: null
                                    })
                                })
                            })
                        })
                    })
                });

                // Insert fails
                mockSupabase.from.mockReturnValueOnce({
                    insert: jest.fn().mockReturnValue({
                        select: jest.fn().mockReturnValue({
                            single: jest.fn().mockResolvedValue({
                                data: null,
                                error: {
                                    code: '23505',
                                    message: 'duplicate key'
                                }
                            })
                        })
                    })
                });
            }

            jest.useFakeTimers();

            const savePromise = RecipeController.saveVersion(mockReq as any, mockRes as Response);

            // Fast-forward timers for all retry attempts (100ms * 0 + 100ms * 1 + 100ms * 2 = 300ms)
            await jest.advanceTimersByTimeAsync(1000);

            await savePromise;

            expect(mockRes.status).toHaveBeenCalledWith(500);
            expect(mockRes.json).toHaveBeenCalledWith({
                error: expect.stringContaining('maximum retries')
            });

            jest.useRealTimers();
        });

        it('should handle concurrent original snapshot creation', async () => {
            // First query: no versions exist
            mockSupabase.from.mockReturnValueOnce({
                select: jest.fn().mockReturnValue({
                    eq: jest.fn().mockReturnValue({
                        order: jest.fn().mockReturnValue({
                            limit: jest.fn().mockReturnValue({
                                single: jest.fn().mockResolvedValue({
                                    data: null,
                                    error: { code: 'PGRST116' }
                                })
                            })
                        })
                    })
                })
            });

            // Fetch original recipe
            mockSupabase.from.mockReturnValueOnce({
                select: jest.fn().mockReturnValue({
                    eq: jest.fn().mockReturnValue({
                        single: jest.fn().mockResolvedValue({
                            data: {
                                id: 'recipe-123',
                                title: 'Original',
                                description: 'Test',
                                ingredients: [],
                                instructions: [],
                                chefs_note: null,
                                step0_summary: null,
                                step0_audio_url: null,
                                difficulty: 'easy',
                                cooking_time: 15,
                                created_at: new Date().toISOString()
                            },
                            error: null
                        })
                    })
                })
            });

            // Snapshot insert fails (another request created it)
            mockSupabase.from.mockReturnValueOnce({
                insert: jest.fn().mockResolvedValue({
                    error: {
                        message: 'duplicate key value',
                        code: '23505'
                    }
                })
            });

            // Remix insert succeeds
            mockSupabase.from.mockReturnValueOnce({
                insert: jest.fn().mockReturnValue({
                    select: jest.fn().mockReturnValue({
                        single: jest.fn().mockResolvedValue({
                            data: {
                                id: 'version-2',
                                recipe_id: 'recipe-123',
                                version_number: 2,
                                ...mockReq.body
                            },
                            error: null
                        })
                    })
                })
            });

            await RecipeController.saveVersion(mockReq as any, mockRes as Response);

            // Should succeed even if snapshot creation failed (already exists)
            expect(mockRes.json).toHaveBeenCalledWith({
                success: true,
                version: expect.objectContaining({
                    version_number: 2
                })
            });
        });
    });

    describe('getVersions', () => {
        it('should return all versions for a recipe', async () => {
            mockSupabase.from.mockReturnValueOnce({
                select: jest.fn().mockReturnValue({
                    eq: jest.fn().mockReturnValue({
                        order: jest.fn().mockResolvedValue({
                            data: [
                                { id: 'v3', version_number: 3, title: 'Latest' },
                                { id: 'v2', version_number: 2, title: 'Second' },
                                { id: 'v1', version_number: 1, title: 'Original' }
                            ],
                            error: null
                        })
                    })
                })
            });

            await RecipeController.getVersions(mockReq as any, mockRes as Response);

            expect(mockRes.json).toHaveBeenCalledWith({
                success: true,
                versions: expect.arrayContaining([
                    expect.objectContaining({ version_number: 3 }),
                    expect.objectContaining({ version_number: 2 }),
                    expect.objectContaining({ version_number: 1 })
                ])
            });
        });

        it('should return empty array when no versions exist', async () => {
            mockSupabase.from.mockReturnValueOnce({
                select: jest.fn().mockReturnValue({
                    eq: jest.fn().mockReturnValue({
                        order: jest.fn().mockResolvedValue({
                            data: [],
                            error: null
                        })
                    })
                })
            });

            await RecipeController.getVersions(mockReq as any, mockRes as Response);

            expect(mockRes.json).toHaveBeenCalledWith({
                success: true,
                versions: []
            });
        });
    });
});
