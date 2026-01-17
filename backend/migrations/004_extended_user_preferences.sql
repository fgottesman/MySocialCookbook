-- Extended user preferences: serving size, dietary restrictions, and other preferences
-- This migration adds new columns to the existing user_preferences table

-- Add default_servings column (1-12 range typical for recipes)
ALTER TABLE user_preferences
ADD COLUMN IF NOT EXISTS default_servings INTEGER DEFAULT 4 CHECK (default_servings >= 1 AND default_servings <= 20);

-- Add dietary_restrictions as a text array for multiple selections
ALTER TABLE user_preferences
ADD COLUMN IF NOT EXISTS dietary_restrictions TEXT[] DEFAULT '{}';

-- Add other_preferences as free-form text for custom preferences
ALTER TABLE user_preferences
ADD COLUMN IF NOT EXISTS other_preferences TEXT DEFAULT '';

-- Update the updated_at timestamp when preferences change
CREATE OR REPLACE FUNCTION update_user_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger if it doesn't exist
DROP TRIGGER IF EXISTS update_user_preferences_timestamp ON user_preferences;
CREATE TRIGGER update_user_preferences_timestamp
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_user_preferences_updated_at();
