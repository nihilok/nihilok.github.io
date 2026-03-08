---
layout: post
title: "The Runfile: A Better .env for Commands"
---

Every project has a `.env` file. At some point we all agreed: config values shouldn't live in your head, in Slack DMs, or in a wiki page titled "Dev Setup (OUTDATED)." They should live in a file, in the repo, with a clear name and a clear format.

But we never did the same thing for commands.

## The tribal knowledge problem

Every project has commands that only one or two people know. The database connection string that lives in someone's shell history. The deployment incantation that's "in the README somewhere." The `docker compose` flags that only work if you also remember to pass `--profile dev --build`.

These commands are project knowledge. They're just as important as `DATABASE_URL` or `API_KEY`. But unlike config, we never gave them a standard place to live.

They end up scattered:

- Shell history (per-machine, ephemeral)
- README.md (out of date within a week)
- Slack messages to yourself (unsearchable)
- A `scripts/` directory with eight files, three of which still work
- The brain of that one person who set up the project

When that person goes on holiday, the whole team is Googling.

## What if commands had a `.env`?

A [Runfile](https://runtool.dev/docs) is that file. It lives in the root of your project, it's checked into version control, and it looks like this:

```bash
# @desc Start all services for local development
dev() {
    docker compose --profile dev up --build -d
}

# @desc Run database migrations
migrate() {
    #!/usr/bin/env python
    from alembic import command
    from alembic.config import Config
    command.upgrade(Config("alembic.ini"), "head")
    print("Migrations complete")
}

# @desc Tail logs for a specific service
# @arg service Service name (api|worker|db)
logs(service) {
    docker compose logs -f $service
}

# @desc Run the full local CI check
ci() {
    run lint
    run test
    run build
}
```

New team member joins? `run --list` shows them everything. No README archaeology. No asking around.

```
$ run --list
dev      Start all services for local development
migrate  Run database migrations
logs     Tail logs for a specific service
ci       Run the full local CI check
```

## Why not just a Makefile / scripts directory / README?

**Makefiles** work, but they're hostile to anyone who doesn't already know Make. Tab-vs-spaces, `.PHONY`, arcane variable substitution — it's a build system pretending to be a task runner. And Make targets don't have typed parameters, so anything beyond simple flags requires parsing that nobody can read.

**A `scripts/` directory** fragments your commands across files with no discoverability. You need to read each script to know what it does and what arguments it takes. And there's no way to pass typed arguments without each script implementing its own arg parsing.

**A README** is documentation, not automation. It goes stale the moment someone changes a flag and forgets to update the docs. And there's no way to tell whether the commands in it still work without running them.

A Runfile is executable documentation. The descriptions are the docs. The functions are the automation. They can't drift apart because they're the same thing.

## The `.env` analogy

Think about what `.env` actually solved:

| Before `.env` | After `.env` |
|---|---|
| Config values in your head | Config values in a file |
| Different on every machine | Shared template, local overrides |
| Onboarding: "ask Sarah" | Onboarding: `cp .env.example .env` |
| Tribal knowledge | Committed knowledge |

A Runfile does the same thing for commands:

| Before Runfile | After Runfile |
|---|---|
| Commands in your shell history | Commands in a file |
| Different incantations per person | One canonical version |
| Onboarding: "check the README" | Onboarding: `run --list` |
| Tribal knowledge | Committed knowledge |

## Getting started

```bash
brew install nihilok/tap/runtool
# or
cargo install run
```

Create a `Runfile` in your project root. Add the commands your team keeps asking about. Commit it.

That's it. Your project's commands now have a home.

And if you're working with AI coding agents, `run` exposes these same tools via [MCP](https://modelcontextprotocol.io) — but that's [a story for another post](/deterministic-toolbox-for-claude-code).

The code is on [GitHub](https://github.com/nihilok/run). The docs are at [runtool.dev](https://runtool.dev).
