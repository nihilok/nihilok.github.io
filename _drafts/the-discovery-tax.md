---
layout: post
title: "The Discovery Tax"
---

Every Claude Code session starts the same way. You say "run the tests." The agent says "I'll look for how to run tests in this project."

Then it reads your README. Then your Makefile. Then your `package.json`. Then it tries `make test`. Wrong. `npm test`. Wrong project. It `cat`s the Makefile again, picks a different target, runs it with the wrong arguments. Eventually it gets there.

Six tool calls. 2,500 tokens of context. Gone — before any real work begins.

That's the discovery tax. You pay it every session. The agent forgets everything and starts over. Every time.

## What it actually costs

It's not just the wasted tokens. It's the compound effect:

- **Context pressure.** On long sessions you're already fighting the context window. Burning 2,500 tokens on discovery means you hit compression sooner.
- **Confidence degradation.** Each failed attempt leaves error messages in the context. The agent second-guesses itself. It starts hedging. "Let me try another approach..." You've seen this — the agent starts confidently, hits two errors, and suddenly every response begins with "I apologise for the confusion."
- **Your time.** You're sitting there watching it fumble through files you could have pointed it at in seconds.

## The refund

What if the agent already knew your project's tools before it started?

That's what [MCP](https://modelcontextprotocol.io) is for. Instead of discovering tools by reading files, the agent gets a structured registry: tool names, descriptions, typed parameters, defaults. No reading. No guessing. No retries.

I built a task runner called [run](https://runtool.dev) with a built-in MCP server. You define your tasks in a `Runfile`:

```bash
# @desc Run the test suite
# @arg filter Optional test name filter
test(filter = "") {
    cargo test --workspace --no-fail-fast $filter
}

# @desc Deploy to an environment
# @arg env Target environment (staging|prod)
deploy(env) ./scripts/deploy.sh $env
```

Add it to your Claude Code config:

```json
{
  "mcpServers": {
    "runtool": { "command": "run", "args": ["--serve-mcp"] }
  }
}
```

Now the same interaction looks like this:

```
You:    run the tests
Agent:  [tool] mcp:runtool test → success
```

One tool call. ~100 tokens. Same result next session.

## The maths

| | Without MCP | With MCP |
|---|---|---|
| Tool calls to run tests | ~6 | 1 |
| Context consumed | ~2,500 tokens | ~100 tokens |
| Next session | Starts from scratch | Same registry |
| Reliability | Varies by session | Deterministic |

Over a day of coding sessions, that's thousands of tokens and dozens of tool calls you're not wasting on rediscovery.

The discovery tax is zero.

For the full picture — auto-truncation, security sandboxing, the deterministic skills layer — see [the deep dive](/deterministic-toolbox-for-claude-code).

```bash
brew install nihilok/tap/runfile
```

[GitHub](https://github.com/nihilok/run) · [Docs](https://runtool.dev/docs)
