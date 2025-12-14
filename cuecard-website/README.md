# CueCard Website

Static site that powers [cuecard.dev](https://cuecard.dev) and mirrors the information from the desktop app landing page.

## Purpose

- Showcases CueCard’s positioning, features, and FAQ
- Hosts the privacy policy (`privacy/`) and terms of service (`terms/`)
- Embeds the product demo video from YouTube
- Provides download links to GitHub Releases

## Structure

```
cuecard-website/
├── index.html         # Landing page content
├── styles.css         # Syne/Inter themed layout
├── script.js          # Lightweight interactions (FAQ toggles, animations)
├── assets/            # Favicons, manifest, images
├── privacy/           # Privacy policy HTML
└── terms/             # Terms of service HTML
```

`index.html` is intentionally framework-free to keep the page lightweight and easily deployable to any static host.

## Local Preview

Any static file server works:

```bash
npx serve .
# or
python3 -m http.server 4173
```

Then open `http://localhost:<port>/`.

## Deployment Notes

- The site is optimized for static hosting (GitHub Pages, Netlify, Vercel, Cloudflare Pages, etc.)
- Update `site.webmanifest` and favicons in `assets/` when branding changes
- Remember to keep privacy/terms copies in sync with legal docs used inside the desktop app
