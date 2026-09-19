# AGENTS.md - Instructions for AI Coding Agents

This repository contains the source code, essays, and drafts for **The Hack Job Handbook** (`https://nihilok.github.io`), a technical blog about systems, tooling, AI workflows, and software engineering.

Any AI agent (Claude Code, Cursor, Codex, Antigravity, etc.) operating in this repository must strictly adhere to the instructions and conventions below.

---

## 1. Writing Voice & Style (Non-Negotiable)

All blog posts, drafts, READMEs, and technical write-ups produced or edited in this repo **MUST** conform to [`STYLE_GUIDE.md`](./STYLE_GUIDE.md).

### Core Guidelines Summary
- **The Persona:** *The Pragmatic Senior in the Trenches.* Wry, direct, technically rigorous, humble, zero corporate posturing.
- **Language:** **British English** throughout (*learnt, behaviour, realised, memorised, apologise, maths*).
- **Structure:** Follow the **5-Beat Blueprint**:
  1. *In-Media-Res Cold Open:* Start immediately inside the terminal or failing build. No throat-clearing.
  2. *Name the Pain:* Coin or use sticky nomenclature (*The Discovery Tax, The Silent Ping, The Godfather Session*).
  3. *Fair Teardown of Alternatives:* Acknowledge existing tools with respect and star counts; isolate the exact missing edge.
  4. *The Empirical Contrast:* Provide concrete transcripts or "The Maths" comparison tables.
  5. *Staccato Punchline:* Close with a short, punchy summary sentence and a direct command/receipt.
- **The Banned List:** Never use corporate/AI slop: *delve, seamlessly, empower, game-changer, digital landscape, testament to, revolutionizing*.

---

## 2. Task Runner (`Runfile`)

The repository uses [`run`](https://runtool.dev) (or `runtool`) as its task runner. Use the defined `Runfile` tasks instead of ad-hoc scripts:

| Command | Description |
| :--- | :--- |
| `run drafts` | List all unpublished drafts in `_drafts/` |
| `run posts` | List all published posts in `_posts/` (newest first) |
| `run new_draft "<title>"` | Create a new draft template in `_drafts/<slug>.md` |
| `run publish <draft-filename>` | Move draft from `_drafts/` to `_posts/YYYY-MM-DD-<slug>.md` with today's date |
| `run new_post "<title>"` | Directly create a new post in `_posts/` with today's date |

*If `run` is available as an MCP server (`run --serve-mcp`), invoke these deterministically via tool calls.*

---

## 3. Post Format & Frontmatter

### Published Posts (`_posts/YYYY-MM-DD-<slug>.md`)
```yaml
---
date: YYYY-MM-DD
layout: post
title: "Your Post Title Here"
---

Post content starting immediately with the in-media-res cold open...
```

### Drafts (`_drafts/<slug>.md`)
```yaml
---
layout: post
title: "Your Draft Title Here"
---

Draft content...
```

---

## 4. Agent Rules of Engagement

1. **Do Not Auto-Publish:** Always place new, unreviewed articles into `_drafts/` unless explicitly instructed by the user to publish.
2. **Promoting Drafts:** Use `run publish <filename>` so the date stamp is automatically inserted and the slug is correctly formed.
3. **Commit Conventions:** Keep commit messages clean and declarative:
   - `Add draft: <Title>`
   - `Publish post: <Title>`
   - `Update draft: <Title>`
4. **Git Hygiene:** Pushing to `origin/main` automatically triggers GitHub Pages deployment. Ensure formatting and frontmatter are valid before pushing.
