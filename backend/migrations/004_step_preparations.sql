-- Add step_preparations column to store pre-computed step data
-- This is computed at recipe creation time for instant loading in cooking mode

ALTER TABLE recipes ADD COLUMN IF NOT EXISTS step_preparations JSONB DEFAULT NULL;

-- Example structure:
-- [
--   {
--     "introduction": "Let's start by prepping the veggies!",
--     "subSteps": [{"label": "1-a", "text": "..."}, {"label": "1-b", "text": "..."}],
--     "conversions": [{"original": "1 cup", "metric": "240ml", ...}]
--   },
--   ...
-- ]
