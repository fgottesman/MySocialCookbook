ALTER TABLE public.recipes ADD COLUMN IF NOT EXISTS difficulty text;
ALTER TABLE public.recipes ADD COLUMN IF NOT EXISTS cooking_time text;

ALTER TABLE public.recipe_versions ADD COLUMN IF NOT EXISTS difficulty text;
ALTER TABLE public.recipe_versions ADD COLUMN IF NOT EXISTS cooking_time text;
