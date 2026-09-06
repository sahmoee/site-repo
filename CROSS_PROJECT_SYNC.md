# Cross-project sync

- Product truth comes from `stocked`, `StockedMac`, `Nova`, `The-Sesh`, and `GIR`.
- `stocked/Brand/Stocked-AppIcon-Master.png` owns Stocked's default icon. StockedMac and this
  website consume byte-derived copies; update iOS, macOS, `assets/stocked-app-icon.png`, and
  `assets/products/stocked.png` together before the website deploys.
- `UnifiedWorker` and released apps may consume public files such as `content/recipes.json`; preserve schemas and URLs.
- Netlify publishes the Git production branch; Cloudflare supplies DNS.

Update public pages when shipped features, policies, support paths, or confirmed links change. Coordinate consumed-content schema changes with every client first.
