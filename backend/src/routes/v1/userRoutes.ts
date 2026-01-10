import express from 'express';
import { UserController } from '../../controllers/UserController';
import { authenticate } from '../../middleware/auth';
import { wrapAsync } from '../../middleware/error';
import { validate } from '../../middleware/validate';
import { RegisterDeviceSchema, GetPreferencesSchema } from '../../schemas';

const router = express.Router();

router.post('/register-device', authenticate, validate(RegisterDeviceSchema), wrapAsync(UserController.registerDevice));
router.get('/preferences/:userId', authenticate, validate(GetPreferencesSchema), wrapAsync(UserController.getPreferences));
router.put('/preferences/:userId', authenticate, validate(GetPreferencesSchema), wrapAsync(UserController.updatePreferences));

export default router;
