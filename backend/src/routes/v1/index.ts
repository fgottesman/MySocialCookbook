import express from 'express';
import recipeRoutes from './recipeRoutes';
import userRoutes from './userRoutes';
import aiRoutes from './aiRoutes';

const router = express.Router();

router.use('/recipes', recipeRoutes);
router.use('/users', userRoutes);
router.use('/ai', aiRoutes);

export default router;
