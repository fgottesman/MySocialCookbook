import express from 'express';
import { AiController } from '../../controllers/AiController';
import { authenticate } from '../../middleware/auth';
import { aiLimiter } from '../../middleware/rateLimit';
import { wrapAsync } from '../../middleware/error';
import { validate } from '../../middleware/validate';
import {
    GenerateRecipeSchema,
    RemixRecipeSchema,
    RemixChatSchema,
    ChatCompanionSchema,
    PrepareStepSchema,
    TranscribeAudioSchema,
    SynthesizeSchema
} from '../../schemas';

const router = express.Router();

router.post('/generate', authenticate, aiLimiter, validate(GenerateRecipeSchema), wrapAsync(AiController.generateFromPrompt));
router.post('/remix', authenticate, aiLimiter, validate(RemixRecipeSchema), wrapAsync(AiController.remixRecipe));
router.post('/remix-chat', authenticate, aiLimiter, validate(RemixChatSchema), wrapAsync(AiController.remixChat));
router.post('/chat-companion', authenticate, aiLimiter, validate(ChatCompanionSchema), wrapAsync(AiController.chatCompanion));
router.post('/prepare-step', authenticate, aiLimiter, validate(PrepareStepSchema), wrapAsync(AiController.prepareStep));
router.post('/transcribe', authenticate, aiLimiter, validate(TranscribeAudioSchema), wrapAsync(AiController.transcribeAudio));
router.post('/synthesize', authenticate, validate(SynthesizeSchema), wrapAsync(AiController.synthesize));
export default router;
