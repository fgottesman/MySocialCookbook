-- Recipe Versions Table for storing remix history
-- Run this migration to enable version persistence

CREATE TABLE IF NOT EXISTS public.recipe_versions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  recipe_id uuid REFERENCES public.recipes(id) ON DELETE CASCADE NOT NULL,
  version_number integer NOT NULL DEFAULT 1,
  title text NOT NULL,
  description text,
  ingredients jsonb,
  instructions jsonb,
  chefs_note text,
  changed_ingredients jsonb, -- Array of ingredient names that were changed
  created_at timestamptz DEFAULT now(),
  
  UNIQUE(recipe_id, version_number)
);

-- Index for fast lookups by recipe
CREATE INDEX IF NOT EXISTS idx_recipe_versions_recipe_id ON public.recipe_versions(recipe_id);

-- RLS: Versions inherit access from parent recipe
ALTER TABLE public.recipe_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own recipe versions" ON public.recipe_versions
  FOR SELECT USING (
    recipe_id IN (SELECT id FROM public.recipes WHERE user_id = auth.uid())
  );

CREATE POLICY "Users can insert their own recipe versions" ON public.recipe_versions
  FOR INSERT WITH CHECK (
    recipe_id IN (SELECT id FROM public.recipes WHERE user_id = auth.uid())
  );

CREATE POLICY "Users can update their own recipe versions" ON public.recipe_versions
  FOR UPDATE USING (
    recipe_id IN (SELECT id FROM public.recipes WHERE user_id = auth.uid())
  );

CREATE POLICY "Users can delete their own recipe versions" ON public.recipe_versions
  FOR DELETE USING (
    recipe_id IN (SELECT id FROM public.recipes WHERE user_id = auth.uid())
  );
