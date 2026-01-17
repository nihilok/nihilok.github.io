---
layout: post
title: "Why I Built Another Task Runner"
date: 2026-01-17
---

# Why I Built Another Task Runner

Yes, I know. Another task runner. In 2025. Hear me out.

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

## What I Actually Wanted

I wanted to write tasks the way I think about them:

```bash
# Just deploy the thing
deploy() {
    ./scripts/deploy.sh $1
}
```

But I also wanted:
- Python when I needed real logic (not bash's string manipulation nightmare)
- Node when working with JSON or async operations
- Cross-platform support without conditional hell
- Something AI agents could actually use (more on this in a moment)

## Enter `run`

So I built [run](https://runfile.dev). A Runfile looks like this:

```bash
# Shell for simple stuff
build() cargo build --release

# Python when you need it
analyze() {
    #!/usr/bin/env python
    import json, sys
    with open(sys.argv[1]) as f:
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
deploy() {
    .\scripts\deploy.ps1 $1
}

# @os linux darwin
deploy() {
    ./scripts/deploy.sh $1
}
```

No YAML. No TOML. No `$(word 2,$(subst -, ,$@))`. Just functions.

## The AI Angle

Here's where it gets interesting, perhaps: `run` has a built-in MCP (Model Context Protocol) server.

I was pairing with Claude on some refactoring when I realised: it would be helpful if Claude could just run our tests or deployment checks directly. With MCP support, AI agents can discover and execute your project's tools automatically.

Add some metadata:

```bash
# @desc Deploy to specified environment
# @arg 1:environment string Target environment (staging|prod)
deploy() {
    ./scripts/deploy.sh $1
}
```

Now Claude (or any MCP-compatible agent) knows exactly what this tool does and how to use it.

## Zero Dependencies, Instant Startup

It's a single Rust binary. No runtime. No package.json with 500 dependencies. You run `run deploy staging` and it just works.

## Is This Useful to Anyone Else?

I don't know. Maybe you're happy with Make. Maybe Just works perfectly for you. Maybe your npm scripts are fine. Maybe you've never had a coworker ask you about cryptic variable substitution syntax.

But if you've ever thought "there has to be a simpler way to do this," maybe give it a try:

```bash
brew install nihilok/tap/runfile
```

The code is on [GitHub](https://github.com/nihilok/run). It solves my problems. Maybe it'll solve yours too.

---

*What task runner do you use? What do you wish it did better? I'd genuinely love to hear about it.*
