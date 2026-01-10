import express from 'express';
import { UserController } from '../../controllers/UserController';
import { authenticate } from '../../middleware/auth';
import { wrapAsync } from '../../middleware/error';

const router = express.Router();

router.post('/register-device', authenticate, wrapAsync(UserController.registerDevice));
router.get('/preferences/:userId', authenticate, wrapAsync(UserController.getPreferences));
router.put('/preferences/:userId', authenticate, wrapAsync(UserController.updatePreferences));

export default router;
