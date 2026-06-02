# VeltoKit documentation site

Docusaurus 3 — **English** docs only. Other languages via **Google Translate** (navbar dropdown).

## Run locally

```bash
npm install
npm run start          # http://localhost:3000/veltokit/
npm run start:prod     # build + serve (production-like)
```

**Important:** `baseUrl` is `/veltokit/` — open `http://localhost:3000/veltokit/`, not bare `localhost:3000`.

Deploy: push to `main` (`.github/workflows/deploy-website.yml`) or `npm run deploy`.

## Documentation tree

```text
docs/
  intro.mdx · demo.mdx · quick-start.md · getting-started.md · …
  sdk/ · examples/
```

Edit content in `docs/`. Run `npm run build` before deploy (`onBrokenLinks: throw`).

## Search

Local full-text search is enabled via `@easyops-cn/docusaurus-search-local` (navbar search box, `⌘K` / `Ctrl+K`).

## AI skills (Cursor / Claude)

Downloadable prompt files and setup notes:

- [Skill for Cursor](docs/for-cursor.mdx) → `static/skills/cursor-skill.md`
- [Skill for Claude](docs/for-claude.mdx) → `static/skills/claude-skill.md`
- Hub: [For Cursor Claude](docs/for-cursor-claude.mdx)

## Translation

- Docs are maintained in **English**.
- **Translate** in the navbar uses [Google Translate](https://translate.google.com/) (machine translation; code/API names stay in English).
- Old `/pl/...` URLs redirect to the English pages.

## Related

- [VeltoKit/README.md](../VeltoKit/README.md)
- [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md)
