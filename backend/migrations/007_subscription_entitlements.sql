-- Migration: Add user entitlements and app config for subscription system
-- Created: 2026-01-12

-- ============================================
-- APP CONFIG TABLE (Remote configuration)
-- ============================================
CREATE TABLE IF NOT EXISTS public.app_config (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default configuration with paywall DISABLED (kill switch)
INSERT INTO public.app_config (key, value) VALUES 
('main', '{
    "paywallEnabled": false,
    "entitlements": {
        "starterRecipeCredits": 5,
        "monthlyFreeCredits": 3,
        "starterRemixCredits": 10,
        "voicePreviewSeconds": 60
    },
    "offers": {
        "firstRecipeOfferEnabled": true,
        "firstRecipeOfferDurationSeconds": 3600,
        "firstRecipeOfferDiscountPercent": 50
    },
    "pricing": {
        "monthlyPrice": "$3.99",
        "annualPrice": "$21.99",
        "annualSavings": "Save 45%"
    }
}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- RLS: Anyone can read config (public)
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read app config" ON public.app_config
    FOR SELECT USING (true);

-- Only service role can modify config
CREATE POLICY "Only service role can modify config" ON public.app_config
    FOR ALL USING (auth.role() = 'service_role');

-- ============================================
-- USER ENTITLEMENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.user_entitlements (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Subscription status
    subscription_status TEXT DEFAULT 'free' 
        CHECK (subscription_status IN ('free', 'pro', 'expired')),
    subscription_expires_at TIMESTAMPTZ,
    subscription_product_id TEXT,
    revenuecat_customer_id TEXT,
    
    -- Credits tracking
    recipe_credits_used INTEGER DEFAULT 0,
    remix_credits_used INTEGER DEFAULT 0,
    
    -- Monthly credits
    monthly_credits_claimed_at DATE,
    
    -- First recipe offer tracking
    first_recipe_at TIMESTAMPTZ,
    first_recipe_offer_shown_at TIMESTAMPTZ,
    first_recipe_offer_expires_at TIMESTAMPTZ,
    first_recipe_offer_claimed BOOLEAN DEFAULT FALSE,
    
    -- Upgrade tracking
    upgraded_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS policies
ALTER TABLE public.user_entitlements ENABLE ROW LEVEL SECURITY;

-- Users can read their own entitlements
CREATE POLICY "Users can read own entitlements" ON public.user_entitlements
    FOR SELECT USING (auth.uid() = id);

-- Users can update their own entitlements (for credits tracking)
CREATE POLICY "Users can update own entitlements" ON public.user_entitlements
    FOR UPDATE USING (auth.uid() = id);

-- Service role can do anything (for backend operations)
CREATE POLICY "Service role full access" ON public.user_entitlements
    FOR ALL USING (auth.role() = 'service_role');

-- ============================================
-- AUTO-CREATE ENTITLEMENTS ON USER SIGNUP
-- ============================================
CREATE OR REPLACE FUNCTION public.create_user_entitlements()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_entitlements (id)
    VALUES (NEW.id)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Only create trigger if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created_entitlements'
    ) THEN
        CREATE TRIGGER on_auth_user_created_entitlements
            AFTER INSERT ON auth.users
            FOR EACH ROW EXECUTE FUNCTION public.create_user_entitlements();
    END IF;
END $$;

-- ============================================
-- MONTHLY CREDITS CLAIM FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION public.claim_monthly_credits(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    last_claim DATE;
    credits_to_add INTEGER;
    config_value JSONB;
BEGIN
    -- Get monthly credits amount from config
    SELECT value->'entitlements'->>'monthlyFreeCredits' INTO credits_to_add
    FROM public.app_config WHERE key = 'main';
    
    credits_to_add := COALESCE(credits_to_add::INTEGER, 3);
    
    -- Get last claim date
    SELECT monthly_credits_claimed_at INTO last_claim
    FROM public.user_entitlements WHERE id = p_user_id;
    
    -- If never claimed or claimed in a previous month, grant credits
    IF last_claim IS NULL OR last_claim < DATE_TRUNC('month', CURRENT_DATE) THEN
        UPDATE public.user_entitlements 
        SET 
            monthly_credits_claimed_at = CURRENT_DATE,
            updated_at = NOW()
        WHERE id = p_user_id;
        
        RETURN credits_to_add;
    END IF;
    
    -- Already claimed this month
    RETURN 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- INCREMENT RECIPE CREDITS FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION public.increment_recipe_credits(p_user_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE public.user_entitlements 
    SET 
        recipe_credits_used = recipe_credits_used + 1,
        first_recipe_at = COALESCE(first_recipe_at, NOW()),
        updated_at = NOW()
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- INCREMENT REMIX CREDITS FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION public.increment_remix_credits(p_user_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE public.user_entitlements 
    SET 
        remix_credits_used = remix_credits_used + 1,
        updated_at = NOW()
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
