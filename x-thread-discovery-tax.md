## Tweet 1

Every #ClaudeCode session starts the same way. You say "run the tests." The agent reads your README, your Makefile, tries make test (wrong), npm test (wrong project), tries again with different args. 6 tool calls and ~2,500 tokens gone before any real work begins.

This is the discovery tax. 🧵

## Tweet 2

The problem isn't intelligence — it's discovery. The agent is remarkably good once it knows what to do. The bottleneck is the gap between "run the tests" and the actual command. And it pays this cost every session because it forgets everything and starts over.

## Tweet 3

What if the agent already knew your project's tools?

I built a task runner called RunTool with a built-in MCP server. You define tasks in a Runfile, add it to your config, and the agent gets a structured tool registry — names, descriptions, typed params, defaults. Zero guessing.

## Tweet 4

Before: 6 tool calls, ~2,500 tokens, varies by session
After: 1 tool call, ~100 tokens, deterministic

Same result next session. No rediscovery. The agent operates like a team member who already knows the codebase.

## Tweet 5

Bonus: the MCP server only exposes tool metadata — not implementation. The agent knows deploy takes an environment string. It doesn't know you're sourcing secrets or hitting an internal service. Sandboxing through metadata.

## Tweet 6

It also handles output truncation at the source — keeps the tail (where errors and summaries are), not the head. Full output saved to a file if the agent needs it. Solves a real pain point with #ClaudeCode and #Codex.

## Tweet 7

Skills tell the agent when to act. The Runfile tells it what to do. Deterministic tools + probabilistic reasoning = reliable agent workflows.

Full write-up: https://nihilok.github.io/deterministic-toolbox-for-claude-code
GitHub: https://github.com/nihilok/run

@anthropic #Codex #MCP
