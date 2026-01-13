import express from 'express';
import { RecipeController } from '../controllers/RecipeController';
import { UserController } from '../controllers/UserController';
import { AiController } from '../controllers/AiController';
import { authenticate, authenticateOrLegacy } from '../middleware/auth';
import { aiLimiter, apiLimiter } from '../middleware/rateLimit';
import { wrapAsync } from '../middleware/error';
import { validate } from '../middleware/validate';
import {
    ProcessRecipeSchema,
    ToggleFavoriteSchema,
    RegisterDeviceSchema,
    GetPreferencesSchema,
    GenerateRecipeSchema,
    RemixRecipeSchema,
    RemixChatSchema,
    ChatCompanionSchema,
    PrepareStepSchema,
    TranscribeAudioSchema,
    SynthesizeSchema
} from '../schemas';
import healthRouter from './health';
import subscriptionRouter from './subscriptionRoutes';

/**
 * LEGACY ROUTER - DO NOT ADD NEW FEATURES HERE
 * This router maintains compatibility with older iOS clients 
 * while utilizing the same fortified controllers as v1.
 */
const router = express.Router();

// Mount health check routes
router.use('/health', healthRouter);
// Mount subscription routes (paywall, entitlements, RevenueCat webhook)
router.use('/subscription', subscriptionRouter);
router.use(apiLimiter);

// Recipes
router.post('/process-recipe', authenticateOrLegacy, aiLimiter, validate(ProcessRecipeSchema), wrapAsync(RecipeController.processRecipe));
router.get('/recipes', authenticate, wrapAsync(RecipeController.getFeed));
router.delete('/recipes/:id', authenticate, wrapAsync(RecipeController.deleteRecipe));
router.patch('/recipes/:id/favorite', authenticate, validate(ToggleFavoriteSchema), wrapAsync(RecipeController.toggleFavorite));
router.get('/recipes/:recipeId/versions', authenticate, wrapAsync(RecipeController.getVersions));
router.post('/recipes/:recipeId/versions', authenticate, wrapAsync(RecipeController.saveVersion));

// User
router.post('/register-device', authenticate, validate(RegisterDeviceSchema), wrapAsync(UserController.registerDevice));
router.get('/user-preferences/:userId', authenticate, validate(GetPreferencesSchema), wrapAsync(UserController.getPreferences));
router.put('/user-preferences/:userId', authenticate, validate(GetPreferencesSchema), wrapAsync(UserController.updatePreferences));

// AI
router.post('/generate-recipe-from-prompt', authenticate, aiLimiter, validate(GenerateRecipeSchema), wrapAsync(AiController.generateFromPrompt));
router.post('/remix-recipe', authenticate, aiLimiter, validate(RemixRecipeSchema), wrapAsync(AiController.remixRecipe));
router.post('/remix-chat', authenticate, aiLimiter, validate(RemixChatSchema), wrapAsync(AiController.remixChat));
router.post('/chat-companion', authenticate, aiLimiter, validate(ChatCompanionSchema), wrapAsync(AiController.chatCompanion));
router.post('/prepare-step', authenticate, aiLimiter, validate(PrepareStepSchema), wrapAsync(AiController.prepareStep));
router.post('/transcribe-audio', authenticate, aiLimiter, validate(TranscribeAudioSchema), wrapAsync(AiController.transcribeAudio));
router.post('/synthesize', authenticate, validate(SynthesizeSchema), wrapAsync(AiController.synthesize));

export default router;
