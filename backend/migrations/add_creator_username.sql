-- Add creator_username column to recipes table
-- This stores the original creator's username from social media platforms (TikTok, Instagram, etc.)

ALTER TABLE recipes ADD COLUMN IF NOT EXISTS creator_username TEXT;

-- Add comment for documentation
COMMENT ON COLUMN recipes.creator_username IS 'Username of the original content creator from social media platforms';
