import express from 'express';
import { AiController } from '../../controllers/AiController';
import { authenticate } from '../../middleware/auth';
import { aiLimiter } from '../../middleware/rateLimit';
import { wrapAsync } from '../../middleware/error';

const router = express.Router();

router.post('/generate', authenticate, aiLimiter, wrapAsync(AiController.generateFromPrompt));
router.post('/remix', authenticate, aiLimiter, wrapAsync(AiController.remixRecipe));
router.post('/remix-chat', authenticate, aiLimiter, wrapAsync(AiController.remixChat));
router.post('/chat-companion', authenticate, aiLimiter, wrapAsync(AiController.chatCompanion));
router.post('/prepare-step', authenticate, aiLimiter, wrapAsync(AiController.prepareStep));
router.post('/transcribe', authenticate, aiLimiter, wrapAsync(AiController.transcribeAudio));
router.post('/synthesize', authenticate, wrapAsync(AiController.synthesize));

export default router;
