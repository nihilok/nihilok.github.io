---
layout: post
title: "The Runfile: A Better .env for Commands"
---

It’s 4:45 PM on a Friday. Sarah—the only person who understands the staging deployment—is halfway up a mountain in the Highlands with zero mobile signal.

The staging build just threw exit code 127.

You search Slack. You find three conflicting command snippets across two threads, a dead link to an internal wiki titled *"Dev Setup (OUTDATED — Ask Sarah)"*, and a pinned message from Dave saying: *"Just run the compose script with `--profile dev` and make sure you export `STAGING_KEY` first."* Dave left the company eight months ago.

You’re fumbling through your shell history, guessing at flags, and praying you don't accidentally deploy to production.

Welcome to the tribal incantation.

---

## The Folklore Problem

Ten years ago, we had this exact disease with environment configuration. 

We kept database passwords in sticky notes, API keys in Slack DMs, and staging URLs in our heads. Every time a new developer joined the team, onboarding was a three-day ritual of *"Hey, what port is Redis running on?"* and *"Why does my auth break on localhost?"*

Then someone invented the `.env` file. And at some point, the entire software industry nodded and agreed: configuration values shouldn't live in someone's skull. They belong in a version-controlled template in the project root, with a standard format, clear names, and local overrides.

Yet in 2026, we still treat project *commands* like oral folklore passed down around a campfire.

Every project has commands that only one or two people truly know:
- The database connection string living in someone's `.zsh_history`.
- The migration flag that prevents Alembic from dropping customer columns.
- The three-line `docker compose` incantation required to spin up the local replica set.
- The `scripts/` directory containing nine bash files, four of which were broken by a Node upgrade in 2024.

When the keeper of those incantations goes on holiday, the team grinds to a halt. We call it "developer onboarding," but let's be honest about what it really is: tribal archaeology.

---

## The Alternatives and the Missing Edge

To be fair, people have tried to fix this. But the established tools always leave papercuts:

* **Make** (~standard on every Unix box since 1976): Solid as granite, but actively hostile to anyone who hasn't memorised its syntax. Tab-vs-spaces traps, `.PHONY` boilerplate, and arcane variable substitution like `$(word 2,$(subst -, ,$@))`. Make was designed to build C dependency trees, not to be a developer ergonomics tool.
* **npm scripts**: Fine if your entire stack is TypeScript. But the minute you need cross-platform shell commands, you end up with brittle abominations like `"clean": "rm -rf dist || rmdir /s /q dist"`. It falls apart completely in polyglot monorepos.
* **Just** (~22k stars): By far the best of the modern Make replacements. Clean syntax, recipe parameters, shell completions. But its parameters are untyped positional strings. The moment a task needs genuine logic—like parsing JSON, inspecting an API, or handling complex flags—you're back to wrestling with bash string manipulation.
* **Task (go-task)** (~15k stars): Excellent cross-platform execution via its built-in interpreter. But configuring tasks in deeply nested YAML files feels like writing Kubernetes manifests just to run your test suite.
* **README.md**: Documentation, not automation. A README goes stale the minute someone changes a flag and forgets to update the markdown. It can't run your tests, and it can't validate its own syntax.

We needed a file that does for project commands what `.env` did for project configuration: a clean, standard, executable registry in the project root.

---

## Enter the Runfile

A [Runfile](https://runtool.dev/docs) is that file. It lives in the root of your repository, it’s checked into git, and it looks like this:

```bash
# @desc Start all local development services
dev() {
    docker compose --profile dev up --build -d
}

# @desc Run database migrations safely
migrate() {
    #!/usr/bin/env python
    from alembic import command
    from alembic.config import Config
    command.upgrade(Config("alembic.ini"), "head")
    print("✓ Migrations applied cleanly")
}

# @desc Tail logs for a specific service
# @arg service Target service (api|worker|db)
logs(service) {
    docker compose logs -f $service
}

# @desc Deploy to an environment
# @arg env Target environment (staging|prod)
# @arg tag Image tag to deploy
deploy(env, tag = "latest") {
    echo "Deploying $tag to $env..."
    kubectl set image deployment/app app=registry.example.com/app:$tag -n $env
    kubectl rollout status deployment/app -n $env
}

# @desc Run the full local CI pipeline
ci() {
    run lint
    run test
    run build
}
```

Notice what’s happening here:

1. **Self-Documenting Metadata:** `# @desc` and `# @arg` turn your functions into self-documenting CLI commands with zero boilerplate.
2. **Inline Polyglot Scripts:** When bash string manipulation gets hairy, you don't need a separate script file. Drop an inline `#!/usr/bin/env python` or `#!/usr/bin/env node` shebang right inside the function.
3. **Typed Validation:** Parameters can define allowable values (`staging|prod`) and defaults (`tag = "latest"`). If someone runs `run deploy production`, `run` catches the invalid value before the command ever touches your cluster.
4. **Composability:** Functions call other functions. `run ci` runs your linter, tests, and build in order, stopping on the first failure.

When a new engineer joins the team, they don't have to read three Confluence pages or ping Sarah on Slack. They clone the repo and type:

```text
$ run --list
dev      Start all local development services
migrate  Run database migrations safely
logs     Tail logs for a specific service
deploy   Deploy to an environment
ci       Run the full local CI pipeline
```

No README archaeology. No faffing. No guessing.

---

## The Maths

Think about what `.env` actually solved for configuration, and compare it to what a Runfile does for commands:

| Dimension | The Tribal Folklore | The Runfile |
|---|---|---|
| **Location** | Shell history, Slack pins, stale READMEs | Single `Runfile` in project root |
| **New Hire Onboarding** | 2–4 hours of broken scripts & Slack DMs | 30 seconds (`run --list`) |
| **Documentation Drift** | README guarantees to rot within weeks | Zero drift (descriptions *are* the CLI help) |
| **Complex Logic** | 8 unmaintained files in `scripts/` | Clean inline Python, Node, or Bash |
| **Safety & Validation** | Fat-fingered flags hit production | Built-in argument parsing & value guards |
| **AI Agent Discovery** | Agents waste ~2,500 tokens reading READMEs | Deterministic MCP tools out of the box |

---

## The Receipt

Stop making your team memorise flags. Stop treating project workflows like oral folklore.

Your configuration has a `.env`. Your commands deserve one too.

```bash
# macOS
brew install nihilok/tap/runtool

# Arch Linux
yay -S runtool

# Cargo
cargo install run
```

Drop a `Runfile` in your repository root, commit it, and put the kettle on.

[GitHub](https://github.com/nihilok/run) · [Docs](https://runtool.dev/docs)
