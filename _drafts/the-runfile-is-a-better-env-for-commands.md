---
layout: post
title: "The Runfile is a Better .env for Commands"
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
# @desc Query the project database
# @arg query SQL query to run
db(query) {
    psql "postgresql://app:secret@db.internal:5432/myapp" -c "$query"
}

# @desc Open SSH tunnel to staging DB
tunnel() {
    ssh -N -L 5433:staging-db.internal:5432 bastion.example.com
}

# @desc Seed the dev database
seed() {
    #!/usr/bin/env python
    import json
    from pathlib import Path
    import subprocess
    for fixture in sorted(Path("fixtures").glob("*.sql")):
        print(f"Loading {fixture.name}...")
        subprocess.run(["psql", DB_URL, "-f", str(fixture)], check=True)
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
db       Query the project database
tunnel   Open SSH tunnel to staging DB
seed     Seed the dev database
ci       Run the full local CI check
```

## Why not just a Makefile / scripts directory / README?

**Makefiles** work, but they're hostile to anyone who doesn't already know Make. Tab-vs-spaces, `.PHONY`, `$(word 2,$(subst -, ,$@))` — it's a build system pretending to be a task runner.

**A `scripts/` directory** fragments your commands across files with no discoverability. You need to read each script to know what it does and what arguments it takes.

**A README** is documentation, not automation. It goes stale the moment someone changes a flag and forgets to update the docs.

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
brew install nihilok/tap/runfile
# or
cargo install run
```

Create a `Runfile` in your project root. Add the commands your team keeps asking about. Commit it.

That's it. Your project's commands now have a home.

The code is on [GitHub](https://github.com/nihilok/run). The docs are at [runtool.dev](https://runtool.dev).
