import express from 'express';
import { RecipeController } from '../../controllers/RecipeController';
import { authenticate } from '../../middleware/auth';
import { aiLimiter } from '../../middleware/rateLimit';
import { wrapAsync } from '../../middleware/error';
import { validate } from '../../middleware/validate';
import { ProcessRecipeSchema, ToggleFavoriteSchema, SaveVersionSchema } from '../../schemas';

const router = express.Router();

router.post('/process', authenticate, aiLimiter, validate(ProcessRecipeSchema), wrapAsync(RecipeController.processRecipe));
router.get('/feed', authenticate, wrapAsync(RecipeController.getFeed));
router.delete('/:id', authenticate, wrapAsync(RecipeController.deleteRecipe));
router.post('/:id/favorite', authenticate, validate(ToggleFavoriteSchema), wrapAsync(RecipeController.toggleFavorite));
router.get('/:recipeId/versions', authenticate, wrapAsync(RecipeController.getVersions));
router.post('/:recipeId/versions', authenticate, validate(SaveVersionSchema), wrapAsync(RecipeController.saveVersion));

export default router;
