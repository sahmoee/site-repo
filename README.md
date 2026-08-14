# Sowens Studios website

Static source for [sowensstudios.com](https://sowensstudios.com).

## Public sections

- `/` — studio overview and complete product portfolio
- `/apps/` and `/apps/{product}/` — portfolio and dedicated product pages
- `/updates/` — public studio and product milestones
- `/press/` — studio boilerplate, product summaries, and brand mark
- `/support/` — Netlify-backed support intake
- `/privacy/` and `/terms/` — portfolio-wide policies

The site uses system fonts, first-party assets, and a small dependency-free navigation script. Add store links only after their public URLs are confirmed.

## Publishing flow

1. Edit and preview this repository locally.
2. Commit reviewed public website files to `master`.
3. Push to `sahmoee/site-repo` on GitHub.
4. Netlify builds the connected production branch and publishes the immutable deploy.
5. `sowensstudios.com` and `www.sowensstudios.com` serve that Netlify deploy through authoritative Cloudflare DNS.

Production should be configured in Netlify to require Git-based deploys. Do not use drag-and-drop or direct production deploys because they bypass repository history and review.

## Security and configuration

- The site contains no credentials. Never commit `.env` files, API keys, passwords, certificates, private keys, QA reports, or private agent/continuity files.
- Public configuration lives in `netlify.toml`, `_headers`, and `_redirects`.
- Secret server-side values, if functions are added later, belong in Netlify environment variables marked as secret and scoped only to Functions and Production.
- DNS is managed in Cloudflare. Namecheap remains the registrar. Netlify manages the certificate used by the website.
- User uploads and private app files do not belong in this repository or in static Netlify assets.

## Content

- `index.html`, legal pages, `assets/`, and `_redirects` are the public website.
- `content/recipes.json` is a public catalog consumed by existing integrations and is validated by GitHub Actions.
- Large public media should use the studio media/CDN service with versioned URLs; private media should use authenticated object storage.

Local AI instructions, handoffs, and cross-project notes are intentionally excluded from GitHub.
