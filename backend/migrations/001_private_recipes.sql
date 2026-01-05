-- Migration: Make recipes private to their owners
-- This ensures only the user who created a recipe can view it

-- Drop the old public viewing policy
DROP POLICY IF EXISTS "Recipes are viewable by everyone" ON public.recipes;

-- Create new private viewing policy - users can only see their own recipes
CREATE POLICY "Users can view their own recipes" ON public.recipes
  FOR SELECT USING (auth.uid() = user_id);
