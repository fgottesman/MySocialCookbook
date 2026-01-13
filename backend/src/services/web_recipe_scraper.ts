import axios from 'axios';
import cheerio from 'cheerio';
import logger from '../utils/logger';

type CheerioRoot = ReturnType<typeof cheerio.load>;

export interface WebRecipeData {
    title?: string;
    description?: string;
    ingredients?: string[];
    instructions?: string[];
    imageUrl?: string;
    cookTime?: string;
    prepTime?: string;
    totalTime?: string;
    yield?: string;
    author?: string;
    rawText: string;
    sourceUrl: string;
    hasStructuredData: boolean;
}

/**
 * Service to scrape recipe data from web pages.
 * Supports JSON-LD structured data (schema.org Recipe) and plain text extraction.
 */
export class WebRecipeScraper {
    private static readonly USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

    /**
     * Known recipe website domains that we should try to scrape.
     * This helps identify when a URL is a recipe page vs a video.
     */
    private static readonly RECIPE_DOMAINS = [
        'nytimes.com/recipes',
        'cooking.nytimes.com',
        'allrecipes.com',
        'foodnetwork.com',
        'epicurious.com',
        'bonappetit.com',
        'seriouseats.com',
        'food52.com',
        'tasty.co',
        'delish.com',
        'simplyrecipes.com',
        'budgetbytes.com',
        'skinnytaste.com',
        'minimalistbaker.com',
        'halfbakedharvest.com',
        'smittenkitchen.com',
        'thekitchn.com',
        'eatingwell.com',
        'cookieandkate.com',
        'loveandlemons.com',
        'pinchofyum.com',
        'recipetineats.com',
        'joshuaweissman.com',
        'bbc.co.uk/food',
        'bbcgoodfood.com',
        'jamieoliver.com',
        'marthastewart.com'
    ];

    /**
     * Video platform domains that should NOT be treated as web recipes.
     */
    private static readonly VIDEO_DOMAINS = [
        'youtube.com',
        'youtu.be',
        'tiktok.com',
        'instagram.com',
        'facebook.com/watch',
        'facebook.com/reel',
        'vimeo.com'
    ];

    /**
     * Determines if a URL is likely a web recipe page (vs a video).
     */
    static isWebRecipeUrl(url: string): boolean {
        const lowerUrl = url.toLowerCase();

        // First check if it's a known video platform
        for (const videoDomain of this.VIDEO_DOMAINS) {
            if (lowerUrl.includes(videoDomain)) {
                return false;
            }
        }

        // Check if it's a known recipe website
        for (const recipeDomain of this.RECIPE_DOMAINS) {
            if (lowerUrl.includes(recipeDomain)) {
                return true;
            }
        }

        // Check for common recipe URL patterns
        if (lowerUrl.includes('/recipe/') || lowerUrl.includes('/recipes/')) {
            return true;
        }

        return false;
    }

    /**
     * Fetches and parses a web recipe page.
     * Extracts structured data (JSON-LD) if available, plus raw text for AI processing.
     */
    async scrapeRecipe(url: string): Promise<WebRecipeData> {
        logger.info(`Scraping web recipe from: ${url}`);

        const html = await this.fetchPage(url);
        const $ = cheerio.load(html);

        // Try to extract structured recipe data (JSON-LD)
        const structuredData = this.extractJsonLd($);

        // Extract clean text content for AI processing
        const rawText = this.extractTextContent($);

        // Extract the best available image
        const imageUrl = this.extractImage($, structuredData);

        const result: WebRecipeData = {
            sourceUrl: url,
            rawText,
            hasStructuredData: structuredData !== null,
            imageUrl
        };

        if (structuredData) {
            logger.info('Found JSON-LD structured recipe data');
            result.title = structuredData.name;
            result.description = structuredData.description;
            result.ingredients = this.normalizeIngredients(structuredData.recipeIngredient);
            result.instructions = this.normalizeInstructions(structuredData.recipeInstructions);
            result.cookTime = structuredData.cookTime;
            result.prepTime = structuredData.prepTime;
            result.totalTime = structuredData.totalTime;
            result.yield = structuredData.recipeYield;
            result.author = this.extractAuthor(structuredData.author);
        } else {
            logger.info('No JSON-LD found, will rely on AI extraction');
            // Try to extract title from page
            result.title = $('h1').first().text().trim() || $('title').text().trim();
        }

        return result;
    }

    private async fetchPage(url: string): Promise<string> {
        try {
            const response = await axios.get(url, {
                headers: {
                    'User-Agent': WebRecipeScraper.USER_AGENT,
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                    'Accept-Language': 'en-US,en;q=0.5'
                },
                timeout: 15000,
                maxRedirects: 5
            });
            return response.data;
        } catch (error: any) {
            logger.error(`Failed to fetch recipe page: ${error.message}`);
            throw new Error(`Could not fetch recipe page: ${error.message}`);
        }
    }

    private extractJsonLd($: CheerioRoot): any | null {
        const scripts = $('script[type="application/ld+json"]');

        for (let i = 0; i < scripts.length; i++) {
            try {
                const content = $(scripts[i]).html();
                if (!content) continue;

                const data = JSON.parse(content);

                // Handle @graph arrays (common in WordPress sites)
                if (data['@graph'] && Array.isArray(data['@graph'])) {
                    const recipe = data['@graph'].find((item: any) =>
                        item['@type'] === 'Recipe' ||
                        (Array.isArray(item['@type']) && item['@type'].includes('Recipe'))
                    );
                    if (recipe) return recipe;
                }

                // Direct Recipe type
                if (data['@type'] === 'Recipe' ||
                    (Array.isArray(data['@type']) && data['@type'].includes('Recipe'))) {
                    return data;
                }

                // Array of objects
                if (Array.isArray(data)) {
                    const recipe = data.find((item: any) =>
                        item['@type'] === 'Recipe' ||
                        (Array.isArray(item['@type']) && item['@type'].includes('Recipe'))
                    );
                    if (recipe) return recipe;
                }
            } catch (e) {
                // JSON parse error, continue to next script
            }
        }

        return null;
    }

    private extractTextContent($: CheerioRoot): string {
        // Remove script, style, nav, footer elements
        $('script, style, nav, footer, header, aside, .advertisement, .ad, [class*="sidebar"]').remove();

        // Get the main content
        const mainContent = $('main, article, [role="main"], .recipe, .recipe-content, #recipe').first();
        const contentElement = mainContent.length ? mainContent : $('body');

        // Extract text with some structure preserved
        const text = contentElement.text()
            .replace(/\s+/g, ' ')
            .replace(/\n\s*\n/g, '\n')
            .trim();

        // Limit text length for AI processing
        return text.substring(0, 15000);
    }

    private extractImage($: CheerioRoot, structuredData: any): string | undefined {
        // Try structured data first
        if (structuredData?.image) {
            if (typeof structuredData.image === 'string') {
                return structuredData.image;
            }
            if (Array.isArray(structuredData.image) && structuredData.image.length > 0) {
                const firstImage = structuredData.image[0];
                return typeof firstImage === 'string' ? firstImage : firstImage?.url;
            }
            if (structuredData.image.url) {
                return structuredData.image.url;
            }
        }

        // Try Open Graph image
        const ogImage = $('meta[property="og:image"]').attr('content');
        if (ogImage) return ogImage;

        // Try Twitter image
        const twitterImage = $('meta[name="twitter:image"]').attr('content');
        if (twitterImage) return twitterImage;

        // Try first large image in content
        const mainImage = $('img[src*="recipe"], img[class*="recipe"], article img').first().attr('src');
        if (mainImage) return mainImage;

        return undefined;
    }

    private normalizeIngredients(ingredients: any): string[] | undefined {
        if (!ingredients) return undefined;
        if (Array.isArray(ingredients)) {
            return ingredients.map(ing => {
                if (typeof ing === 'string') return ing.trim();
                if (ing.text) return ing.text.trim();
                return String(ing).trim();
            }).filter(Boolean);
        }
        return undefined;
    }

    private normalizeInstructions(instructions: any): string[] | undefined {
        if (!instructions) return undefined;

        if (Array.isArray(instructions)) {
            return instructions.flatMap(inst => {
                if (typeof inst === 'string') return inst.trim();
                if (inst.text) return inst.text.trim();
                if (inst['@type'] === 'HowToStep' && inst.text) return inst.text.trim();
                if (inst['@type'] === 'HowToSection' && inst.itemListElement) {
                    return this.normalizeInstructions(inst.itemListElement) || [];
                }
                return [];
            }).filter(Boolean);
        }

        if (typeof instructions === 'string') {
            return instructions.split(/\n|\.(?=\s)/).map(s => s.trim()).filter(Boolean);
        }

        return undefined;
    }

    private extractAuthor(author: any): string | undefined {
        if (!author) return undefined;
        if (typeof author === 'string') return author;
        if (author.name) return author.name;
        if (Array.isArray(author) && author.length > 0) {
            return this.extractAuthor(author[0]);
        }
        return undefined;
    }
}
