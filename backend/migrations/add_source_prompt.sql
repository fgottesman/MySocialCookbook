-- Add source_prompt column to recipes table
-- This stores the AI prompt used to generate recipes for proper attribution

ALTER TABLE recipes ADD COLUMN IF NOT EXISTS source_prompt TEXT;

-- Add comment for documentation
COMMENT ON COLUMN recipes.source_prompt IS 'The user prompt that was used to generate this AI recipe';
