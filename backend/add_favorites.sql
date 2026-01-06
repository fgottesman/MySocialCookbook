-- Add is_favorite column to recipes table
ALTER TABLE public.recipes 
ADD COLUMN IF NOT EXISTS is_favorite boolean DEFAULT false;

-- Create index for faster favorite queries
CREATE INDEX IF NOT EXISTS idx_recipes_user_favorite 
ON public.recipes(user_id, is_favorite) 
WHERE is_favorite = true;

-- Add chefs_note column if it doesn't exist (for remix feature)
ALTER TABLE public.recipes 
ADD COLUMN IF NOT EXISTS chefs_note text;
