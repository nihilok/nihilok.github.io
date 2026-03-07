---
layout: post
title: "Why I Built Another Task Runner"
date: 2026-01-17
---

Yes, I know. Another task runner. In 2026. Let me explain why.

## The Problem

I'm not a Make expert. But somehow I became the person people ask when they need to add a task to our Makefile.

Last week it was "How do I pass an environment variable to this target?" The week before: "Why does this only work if I add a tab character?" And the week before that it was me forgetting to add a task to `.PHONY`.

Every time, I'm Googling the same things they could be Googling. Our build process has things like this:

```makefile
deploy-%: guard-% check-git-clean
	@$(eval ENV := $(word 2,$(subst -, ,$@)))
	./scripts/deploy.sh $(ENV)
```

If you understand what `$(word 2,$(subst -, ,$@))` does without looking it up, congratulations — you're in the 1% of developers who've memorised Make's arcane variable substitution syntax.

## The Alternatives Weren't Much Better

Other repos in the company use npm scripts. Some have custom Python CLI packages run with uv. Every project has its own approach.

The npm scripts repos hit the same cross-platform issues. Shell commands that work fine on Mac and Linux fail on Windows. You end up with:

```json
{
  "clean": "rm -rf dist || rmdir /s /q dist",
  "build": "NODE_ENV=production webpack || set NODE_ENV=production && webpack"
}
```

Ugly. Fragile. And it still broke in random edge cases.

So I looked at the established alternatives.

**Just** (~22k stars) is the closest thing to what I wanted: a clean `justfile` with Make-inspired syntax, recipe parameters, shell completions. But parameters have no type annotations — they're positional strings and that's it. Handy for humans, but AI agents can't reliably introspect them.

**Task (go-task)** (~15k stars) impressed me with its built-in POSIX shell interpreter, which gives genuinely consistent cross-platform behaviour without relying on the system shell. But it's shell-only — no inline Python or Node.js. And MCP support is still just a GitHub issue with no implementation.

**Mise** (~25k stars) is arguably the most feature-rich tool in this space, combining dev tool version management (replacing asdf/nvm/pyenv), environment management, and task running in a single binary. It does have an experimental `mise mcp` server, which is genuinely interesting — though it exposes the broader dev environment surface rather than being focused specifically on task execution. For teams already using mise for version management, that breadth is a strength.

The Markdown-based runners — **Mask**, **xc**, **Maid** — are a compelling idea (documentation and automation in one file), but none of them have any MCP story, and Maid hasn't been meaningfully maintained in years.

## What I Actually Wanted

I wanted to write tasks the way I think about them:

```bash
# Just deploy the thing
deploy(environment) {
    ./scripts/deploy.sh $environment
}
```

But I also wanted:

- Python when I needed real logic (not bash's string manipulation nightmare)
- Node when working with JSON or async operations
- Cross-platform support without conditional hell
- Something AI agents could actually use — not as an afterthought, but as a first-class feature

That last point turned out to be the gap nobody had filled properly.

## So I Built `run`

So I built [run](https://runtool.dev). A Runfile looks like this:

```bash
# Shell for simple stuff
build() cargo build --release

# Python when you need it
analyze(file) {
    #!/usr/bin/env python
    import json
    with open(file) as f:
        data = json.load(f)
        print(f"Processed {len(data)} records")
}

# Node works too
process() {
    #!/usr/bin/env node
    const fs = require('fs');
    console.log('Processing...');
}

# Platform-specific versions
# @os windows
deploy(environment) {
    .\scripts\deploy.ps1 $environment
}

# @os linux darwin
deploy(environment) {
    ./scripts/deploy.sh $environment
}
```

No YAML. No TOML. No `$(word 2,$(subst -, ,$@))`. Just functions with named parameters.

### Polyglot Argument Passing

The polyglot model is worth dwelling on — even if you never touch the AI features, this alone is a meaningful improvement over existing tools.

Notice how the Python function above gets `file` as a native Python variable — no `sys.argv[1]`, no `argparse`, no parsing. And it goes further than just strings. If you add a type annotation:

```bash
resize(file, width: int, height: int) {
    #!/usr/bin/env python
    from PIL import Image
    img = Image.open(file)
    img.resize((width, height)).save(file)
    print(f"Resized to {width}x{height}")
}
```

`width` and `height` arrive as actual Python `int`s. You can multiply them, pass them to APIs that expect numbers, use them in range expressions — no `int(sys.argv[2])` boilerplate. The same applies to Node.js, Ruby, and PowerShell: RunTool generates the appropriate variable declarations for each interpreter, with type-correct values.

Compare this to the typical polyglot task runner experience: you write a shebang script, and everything arrives as a string. You spend the first few lines of every script parsing and converting arguments. It's not a lot of code, but it's friction — and it's the kind of friction that makes people reach for a full CLI framework instead of a quick task.

Just supports multiple languages too, via shebangs — but each shebang recipe has to be a separate named recipe. RunTool lets you mix languages within a single file using function-scoped shebangs. And the `@os` attribute lets you define the *same function name* with different implementations per platform, which is more ergonomic than Task's `platforms` filter or mise's `run_windows` property.

## The AI Integration

Here's where it gets interesting: `run` has a built-in MCP (Model Context Protocol) server.

I was pairing with Claude Code on some refactoring (_it_ was driving 🙈) when I realised: it would be helpful if Claude could just run our tests or deployment checks directly. With MCP support, AI agents can discover and execute your project's tools automatically, and use the exact same tools that you use.

Add some metadata:

```bash
# @desc Deploy to specified environment
# @arg environment Target environment (staging|prod)
deploy(environment) {
    ./scripts/deploy.sh $environment
}
```

The function signature *is* the schema. Claude (or any MCP-compatible agent) sees a tool called `deploy` with a required `environment` parameter — no guessing, no multi-step discovery, no verbose Markdown explanations needed. Type annotations and defaults work too:

```bash
# @desc Scale a service
# @arg service The service name
# @arg replicas Number of instances
scale(service, replicas: int = 1) {
    docker compose scale $service=$replicas
}
```

The `@desc` and `@arg` annotations serve dual purposes: they generate human-readable help text *and* provide structured metadata that MCP clients use for tool discovery and invocation. That's architecturally different from Just's approach, where three independent community-built MCP servers have to parse the justfile format externally without any structured argument metadata to work with.

There's a useful security property here too: the MCP server only exposes the annotations — the function name, description, and argument signatures. The implementation is not surfaced. An agent knows that `deploy` takes an `environment` argument of type string; it doesn't know (or need to know) that internally it shells out to `./scripts/deploy.sh`, or that there's a secrets file being sourced, or any other implementation detail. If the agent wants to read the Runfile itself it can, but that's an explicit read operation — not something the MCP server hands over automatically. You can give agents access to your tooling without giving them a map of your internals.

As of early 2026, the landscape looks like this:

| Tool | Polyglot scripting | Typed arguments | MCP integration |
|---|---|---|---|
| **RunTool** | ✅ Shell/Python/Node/Ruby/PS | ✅ Signature types + defaults | ✅ Built-in |
| **Just** | ✅ Via shebangs | ⚠️ Params, no types | ⚠️ 3 third-party servers |
| **Task** | ❌ Shell-only | ⚠️ `requires` + enum | ❌ Requested only |
| **Mise** | ✅ Via shebangs | ✅ usage spec | ✅ Built-in (experimental) |
| **Mask** | ✅ Code block langs | ⚠️ Flags with types | ❌ None |
| **xc** | ❌ Shell-only | ⚠️ Inputs attribute | ❌ None |
| **Make** | ❌ Shell (with quirks) | ❌ None | ⚠️ Third-party only |

RunTool and mise are the only tools with built-in MCP servers. The difference is scope: mise's MCP server exposes its full environment management surface (tools, tasks, versions, env vars), which is powerful if you want an agent that can manage your entire dev environment. RunTool's is narrower by design — purpose-built around task execution and structured argument metadata — which means less surface area to audit and a simpler mental model for what the agent can do.

## Zero Dependencies, Instant Startup

It's a single Rust binary. No runtime. No package.json with 500 dependencies. You run `run deploy staging` and it just works.

And it comes with shell completions out of the box — bash, zsh, fish, and PowerShell. Tab completion for all your tasks, no extra setup required.

## Honestly, the Tradeoffs

I'd be doing you a disservice if I didn't acknowledge what the alternatives have that RunTool doesn't — yet.

**Just** has years of battle-testing, a backwards-compatibility guarantee ("there will never be a just 2.0"), and extensive editor support across VS Code, JetBrains, Helix, Kakoune, and Zed. Its community has built three independent MCP servers. That ecosystem trust takes years to build.

**Task** has something technically impressive that's easy to overlook: its built-in shell interpreter (mvdan/sh) plus built-in Unix utilities means it's genuinely cross-platform without platform-specific shims. If your team has Windows developers and you've suffered through shell compatibility issues, that's a compelling argument.

**Mise** bundles tool version management, environment management, and task running into a single binary — reducing the number of tools a project depends on. If you're already using mise for version management, its experimental MCP support and rich task runner make it the most comprehensive single-binary solution. And its broader MCP surface area is genuinely useful if you want agents that can manage your full dev environment, not just run tasks.

RunTool is a new entrant betting that AI-agent interoperability will become a first-class concern for developer tooling. That bet might be right or wrong. What I can say is: when I'm working alongside Claude Code on a project and it can discover and run the project's tasks through the same interface I do, that workflow genuinely changes how I work.

## Is This Useful to Anyone Else?

I don't know. Maybe you're happy with Make. Maybe Just works perfectly for you. Maybe mise already does everything you need. Maybe you don't care whether your AI agent can introspect your task arguments.

But if you've ever thought "there has to be a simpler way to do this" — whether that's passing typed arguments to a Python task without `argparse`, writing cross-platform tasks without conditional hell, or giving your AI agent access to your project's tools — maybe give it a try:

```bash
brew install nihilok/tap/runfile
```

or

```bash
cargo install run
```

The code is on [GitHub](https://github.com/nihilok/run). It solves my problems. Maybe it'll solve yours too.
