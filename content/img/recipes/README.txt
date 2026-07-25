Recipe images for the Stocked Discover feed.

RULES (updated 2026-07-25):
1. Name files by recipe id: 001.jpg, 002.jpg, ... JPEG, ~1200px wide, <300KB.
2. In content/recipes.json, reference images with ABSOLUTE URLs ONLY:
     "image": "https://api.sowensstudios.com/content/img/recipes/001.jpg"
   That URL is the Cloudflare Worker's 30-day edge cache in front of this repo
   (CONTENT_ORIGIN = raw.githubusercontent.com/sahmoee/site-repo/master).
   Relative paths are FORBIDDEN: the app resolves them against
   cdn.sowensstudios.com, which no longer hosts this content.
3. Until a real image exists, leave "image": "" — the app shows a styled fallback.
