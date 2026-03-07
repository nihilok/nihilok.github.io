---
layout: post
title: "How I Gave Claude Code a Deterministic Toolbox (and Stopped It Guessing How to Run My Project)"
date: 2026-03-07
---

If you've spent any real time pairing with Claude Code, you've seen the dance.

You ask it to run the tests. It reads your README. Maybe it finds a `Makefile`, maybe a `package.json`, maybe a `scripts/` directory. It tries `make test`. That fails. It tries `npm test`. Wrong project. It `cat`s your Makefile, parses the targets, picks one, runs it with the wrong arguments. Three tool calls and 2,000 tokens later, it's running the right command — until next session, when it's forgotten everything and does the dance again.

This is the discovery tax. Every Claude Code session pays it, and it compounds: each failed attempt burns context window, each retry eats tokens, and the agent's confidence degrades as it accumulates error messages. On a long session where you're already bumping up against context limits, those wasted tokens matter.

I built a tool called [run](https://runtool.dev) that fixes this. Here's how.

## The problem isn't intelligence, it's discovery

Claude Code is remarkably good at executing tasks once it knows what to do. The bottleneck is the gap between "I need to run the tests" and "the command is `cargo test --workspace --no-fail-fast`". Bridging that gap currently requires the agent to:

1. **Read files** to discover what's available (README, Makefile, package.json, scripts/)
2. **Infer intent** from naming conventions and comments
3. **Guess at arguments** — is it `make deploy ENV=staging` or `make deploy-staging` or `./scripts/deploy.sh staging`?
4. **Fail and retry** when the guess is wrong
5. **Forget everything** next session and repeat from step 1

Each of these steps consumes tool calls and context. And because there's no structured metadata — just files full of text — the agent is doing natural language parsing of shell scripts, which is exactly the kind of task where LLMs are most likely to make subtle mistakes.

## What if the agent already knew?

MCP (Model Context Protocol) lets you expose tools to AI agents with structured schemas — name, description, typed parameters, defaults. The agent doesn't discover tools by reading files; it discovers them through a protocol designed for exactly this purpose.

[RunTool](https://runtool.dev) is a task runner with a built-in MCP server. You define your project's tasks in a `Runfile`:

```
# @desc Run the full test suite
# @arg filter Optional test name filter
test(filter = "") {
    cargo test --workspace --no-fail-fast $filter
}

# @desc Deploy to the specified environment
# @arg environment Target environment (staging|prod)
deploy(environment) {
    ./scripts/deploy.sh $environment
}

# @desc Resize an image using Python
# @arg file Path to the image file
# @arg width Target width in pixels
# @arg height Target height in pixels
resize(file, width: int, height: int) {
    #!/usr/bin/env python
    from PIL import Image
    img = Image.open(file)
    img.resize((width, height)).save(file)
    print(f"Resized to {width}x{height}")
}
```

Add `run` as an MCP server in your Claude Code config:

```json
{
  "mcpServers": {
    "run": {
      "command": "run",
      "args": ["--serve-mcp"]
    }
  }
}
```

Now when Claude Code starts a session, it immediately sees a tool registry: `test` takes an optional string `filter`; `deploy` takes a required string `environment`; `resize` takes a `file` string plus `width` and `height` integers. No file reading. No guessing. No retry loops. Zero discovery tax.

## Before and after

**Before (no MCP, typical Claude Code session):**

```
Human: run the tests

Claude Code: I'll look for how to run tests in this project.
  [tool] cat README.md                           → 800 tokens
  [tool] ls scripts/                              → 50 tokens
  [tool] cat Makefile                             → 600 tokens
  [tool] make test                                → fails (wrong target name)
  [tool] make tests                               → fails (missing argument)
  [tool] make tests FILTER=""                     → success

  Total: 6 tool calls, ~2,500 tokens of context consumed
  Next session: starts from scratch
```

**After (RunTool MCP):**

```
Human: run the tests

Claude Code: I'll run the test suite.
  [tool] mcp:run test                             → success

  Total: 1 tool call, ~100 tokens of context consumed
  Next session: same tool registry, same result
```

That's not a marginal improvement. It's the difference between an agent that fumbles through your project and one that operates like a team member who already knows the codebase.

## Auto-truncation: solving the output problem

There's a second problem that anyone using MCP tools with Claude Code or Codex has run into: output truncation. Claude Code and Codex both impose limits on tool output — and when your test suite dumps 500 lines of results, the agent gets a chopped-up view with the middle missing, which is often exactly where the useful information is.

RunTool handles this at the MCP server level. By default, tool output is capped at approximately 300 tokens (~1KB) — enough for the agent to see whether something passed or failed and get the key details, without blowing up the context window. Critically, `run` keeps the _tail_ of the output, not the head. That's where the useful information almost always is: the test results summary, the final error message, the exit status. When output exceeds the limit, `run` truncates from the top and saves the full output to a file. The agent gets the actionable ending plus a file path it can read selectively if it needs the full details. The threshold is configurable in the environment, so you can tune it up or down to match your context budget.

Compare this to what happens without it: Claude Code and Codex both impose their own truncation on tool output — Codex chops at 256 lines or 10KB using a head+tail strategy that drops the middle, which is often exactly where the useful information is. RunTool's approach is smarter because it happens at the source, before the agent's own limits kick in, it prioritises the part of the output you actually care about, and the full output is always recoverable.

## The security argument: sandboxing through metadata

Here's something that's easy to overlook but has real implications for how you think about agent access.

When Claude Code reads your Makefile or scripts to discover tasks, it sees _everything_: implementation details, file paths, secrets files being sourced, internal service URLs, database connection strings referenced in scripts. All of that goes into the context window.

RunTool's MCP server exposes _only_ the annotations — function name, description, argument signatures. The implementation stays hidden. The agent knows that `deploy` takes an `environment` argument of type string; it doesn't know that internally it sources `~/.secrets/prod.env` and shells out to an internal deployment service at `deploy.internal.corp:8443`.

This is sandboxing through metadata. You're giving the agent powerful, well-defined tools without giving it a map of your internals. If the agent wants to read the Runfile itself it can (it's just a file), but that's an explicit read operation that you could restrict — not something the MCP server hands over automatically.

For teams that are cautious about what their AI agents can see — and you should be — this is a meaningful property.

## The deterministic layer: encoding skills in your Runfile

Claude Code has a concept of "skills" — instructions stored in `.claude/` that tell the agent how to handle specific tasks. Skills are useful, but they're prompts: natural language instructions that the agent interprets probabilistically. They can drift, be misinterpreted, or interact unpredictably with other context.

A Runfile is a deterministic skill layer. When you define:

```
# @desc Run linting with auto-fix
lint() cargo clippy --fix --allow-dirty

# @desc Format all source files
fmt() cargo fmt --all

# @desc Run the full CI pipeline locally
ci() {
    run lint
    run fmt
    run test
}
```

There's no interpretation involved. `ci` runs `lint`, then `fmt`, then `test`, in that order, every time. The agent doesn't need to figure out your CI pipeline from scattered config files — it has a single, composable tool that does exactly what you've defined.

This is particularly powerful when combined with skills. You can write a `.claude/` skill that says "before committing, always run the `ci` tool" — and because `ci` is a deterministic MCP tool rather than a set of natural language instructions, the behaviour is predictable and auditable.

Skills tell the agent _when_ to act. The Runfile tells it _what_ to do. Keeping those concerns separate makes both more reliable.

## Getting started

Install `run`:

```bash
brew install nihilok/tap/runfile
# or
cargo install run
```

Create a `Runfile` in your project root with your common tasks. Add `@desc` and `@arg` annotations for anything you want the agent to discover. Add `run` as an MCP server in your Claude Code config.

The [documentation](https://runtool.dev/docs) covers the full syntax, including polyglot scripting (Python, Node, Ruby, PowerShell in the same file), cross-platform `@os` variants, and command composition.

The code is on [GitHub](https://github.com/nihilok/run). If you're working with Claude Code daily and you're tired of watching it guess how to run your project, give it a try.
