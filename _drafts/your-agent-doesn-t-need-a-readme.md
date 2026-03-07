---
layout: post
title: "Your Agent Doesn't Need a README"
---

We write READMEs for humans. Structured headings, prose explanations, code blocks with context. A human reads "To run the tests, use `cargo test --workspace`" and knows what to do.

An AI agent reads the same sentence and has to:

1. Find the README
2. Parse the natural language
3. Extract the command from the surrounding prose
4. Hope the README is up to date
5. Hope there aren't flags mentioned three paragraphs later that are also required

It works. Eventually. But it's the wrong interface for the job.

## Structured beats unstructured

READMEs are documentation. They're great at explaining *why*. They're terrible at telling a machine *what* — because the machine has to do natural language parsing on a document designed for humans, and extract structured information from an unstructured format.

What agents actually need is a schema: a tool name, a description, typed parameters, and defaults. That's what [MCP](https://modelcontextprotocol.io) provides.

A [Runfile](https://runtool.dev/docs) gives your project's tools exactly that schema:

```bash
# @desc Run the test suite
# @arg filter Optional test name filter
test(filter = "") {
    cargo test --workspace --no-fail-fast $filter
}
```

The agent doesn't read this file. It receives a structured tool definition over MCP: `test` is a tool, it takes an optional string parameter called `filter`, and here's what it does. No parsing. No ambiguity.

## What the agent sees

**From a README:**

A blob of Markdown. It has to figure out which parts are commands, which parts are commentary, and which parts are outdated. It might get it right. It might try the example from the "Legacy Setup" section that nobody deleted.

**From an MCP tool registry:**

```json
{
  "name": "test",
  "description": "Run the test suite",
  "parameters": {
    "filter": { "type": "string", "description": "Optional test name filter" }
  }
}
```

No ambiguity. No staleness risk. The schema *is* the interface.

## What the agent doesn't see

Here's the other thing: when the agent reads your README to discover commands, it also reads everything else in there. Internal URLs, architecture decisions, deployment details, service names. All of it goes into the context window.

An MCP tool registry exposes *only* the tool interface — name, description, parameters. The implementation stays behind the wall. Your agent gets powerful, well-defined tools without getting a map of your internals.

## Deterministic beats probabilistic

There's a deeper point here. When an agent reads a README and extracts a command, the result is probabilistic. It *probably* gets the right command. It *probably* passes the right flags. But "probably" compounds badly across a session — each probably-correct step increases the chance that one of them isn't.

A Runfile is deterministic. `run test` runs the test suite, with the right flags, every time. The agent doesn't interpret instructions — it calls a tool. There's no gap between what you intended and what executes.

This matters even more when you combine it with Claude Code's [skills](https://docs.anthropic.com/en/docs/claude-code/skills). You can write a skill that says "before committing, always run `ci`" — and because `ci` is a deterministic MCP tool, not a natural language instruction, the behaviour is predictable and auditable. Skills tell the agent *when* to act. The Runfile tells it *what* to do.

## The README is still useful

This isn't an argument against READMEs. Write them for your human teammates. Explain the *why*, the architecture, the gotchas.

But stop expecting your agent to use them as an API. Give it a real one.

```bash
brew install nihilok/tap/runfile
```

[GitHub](https://github.com/nihilok/run) · [Docs](https://runtool.dev/docs)
