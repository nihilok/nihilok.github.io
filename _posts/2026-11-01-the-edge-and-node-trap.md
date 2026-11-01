---
date: 2026-11-01
layout: post
title: "The Edge-and-Node Trap: Why Makefiles Were Never Meant for Tasks"
---

There is a particular flavour of quiet resignation that settles over an engineering team when someone types this into CI:

```bash
make -j$(nproc) all || make -j$(nproc) all || make -j$(nproc) all
```

We laugh because it's absurd. We keep typing it because it passes the build. And we keep using Make because of sheer institutional inertia.

Thibaud recently published a crisp, surgical post titled [*The case against Makefiles*](https://thibaud.space/2026/10/the-case-against-makefiles.html). His thesis is deceptively simple: Make was built in 1976 for C code; modern build systems (like CMake, Meson, or Cargo) have superseded it for compilation; and for everything else, Make is an archaic, brittle square peg forced into a round hole.

He is spot on. But looking closely at why Make breaks down in everyday developer workflows reveals something deeper about the tools we build—and where task runners need to go next.

---

## The Edge-and-Node Trap

Thibaud nails Make’s fundamental architectural mistake in one sentence: Make describes the *edges* of the build graph, not the *nodes*. 

It describes the transformation required to turn one file into another:

```makefile
%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<
```

It says: *if `foo.c` exists and is newer than `foo.o`, run this compiler command.* It has no concept of what an executable is, or what the end goal is. It only understands timestamps on physical files on disk.

In 1976, that was revolutionary. But modern developer workflows are rarely about transforming file extensions. We run database migrations. We spin up Docker containers. We run linters, sync S3 buckets, and kick off deployments. 

None of those things are files.

To make Make work for tasks, you pay **The Phony Tax**:

```makefile
.PHONY: publish-docker
publish-docker: build-docker
	docker image push my-image:latest
```

You have to explicitly lie to Make: *"Ignore your file-timestamp engine. This target isn't a file on disk. Just run it."*

And then you hit the wall that every team eventually hits: **parameters**.

Thibaud uses the exact scenario I’ve watched derail a dozen Slack channels. You want to build two Docker images. In Make, you cannot pass arguments into a target cleanly. So you either copy-paste the rule:

```makefile
.PHONY: build-docker-foo
build-docker-foo:
	docker image build -t my-foo-image docker/my-foo-image

.PHONY: build-docker-bar
build-docker-bar:
	docker image build -t my-bar-image docker/my-bar-image
```

Or you summon an in-house Make wizard who unleashes unholy string substitution hacks:

```makefile
build-docker-%:
	docker image build -t $(subst build-docker-,,$@) docker/$(subst build-docker-,,$@)
```

If someone on your team can read `$(subst build-docker-,,$@)` at 4:30 PM on a Friday without a headache, offer them a cup of tea and ask for their autograph. For the remaining 99% of us, it is brittle, unreadable faffing.

---

## What About Just?

Thibaud’s recommendation for tasks is [**`just`**](https://github.com/casey/just) (~22k stars), and he’s right to praise it.

Casey Rodarmor’s `just` is fantastic. It banished tabs-versus-spaces syntax errors to the dustbin of history. It gave us `--list` out of the box. It introduced clean recipe arguments:

```just
build-docker image:
    docker image build -t {{ image }} docker/{{ image }}
```

If the choice is strictly between a Makefile and a justfile for developer commands, pick `just` every single time. It's a massive ergonomic leap forward.

So why did I spend my weekends building [`run`](https://runtool.dev)?

Because `just` was designed in an era when only biological humans ran tasks in terminals. And even for humans, it leaves two glaring papercuts unresolved.

### 1. The Polyglot Wall

Recipes in `just` are fundamentally shell scripts. That is fine when you are chaining two `docker` or `cargo` commands together. But the moment you need real logic—parsing a JSON response from a remote registry, manipulating dates, checking semver boundaries, or reading a configuration file—you are thrown right back into bash's string manipulation nightmare:

```bash
# Fragile, unreadable, and behaves differently on macOS vs Linux
VERSION=$(cat package.json | grep '"version"' | cut -d '"' -f 4)
```

In `just`, your only escape hatch is writing a standalone script in a `scripts/` folder or using a shebang recipe that dumps the body into a temporary file. Your project's command layer quickly fragments into three different directories.

### 2. The Dual-Citizen CLI (Enter AI Agents)

In 2026, humans aren't the only ones running commands in our terminal. AI coding agents—Claude Code, Antigravity, Cursor, Codex—pair with us all day long.

When an AI agent enters a repository governed by a `Makefile` or a `justfile`, what happens? 

The agent doesn't have an interactive shell intuition. It has to act like a bewildered junior developer on their first morning:
1. It greps the `Makefile` or `justfile`.
2. It tries to figure out what arguments are accepted (are they positional? flags? environment variables?).
3. It guesses. It fails. It inspects the error. It tries again.

You end up paying what I call **The Discovery Tax**: 2,000 prompt tokens and four round trips just to run `cargo test` with a package filter.

---

## What A Modern Task Runner Looks Like

When we built `run`, we started from a simple premise: **tasks are functions, not files.** 

A task has a name, typed arguments, defaults, and optional documentation attributes. And because real-world automation requires real-world languages, you should be able to write shell, Python, or Node right inside the same file:

```bash
# @desc Build and push a container image
# @arg image Target container name
# @arg tag Release tag (defaults to "latest")
publish(image: str, tag = "latest") {
    docker image build -t "$image:$tag" "docker/$image"
    docker image push "$image:$tag"
}

# @desc Verify API payload against schema
validate-spec(file) {
    #!/usr/bin/env python
    import json, sys
    with open(file) as f:
        data = json.load(f)
    print(f"Validated {len(data['routes'])} routes")
}
```

Notice what just happened to Thibaud's Docker dilemma:
- Zero `.PHONY` declarations.
- Zero duplicated rules.
- Zero `$(subst ...)` macro sorcery.
- First-class parameter names with defaults and types.
- A human types `run publish api` or `run publish worker v2.1.0`.

### The Maths: Humans vs. Agents

Because `run` treats tasks as typed functions, it can expose them directly over the Model Context Protocol (MCP) via `run --serve-mcp`. 

Compare what happens when you tell an agent *"build and test the worker service"*:

| Metric | Make / Just | Run (with MCP) |
| :--- | :--- | :--- |
| **Discovery Mechanism** | Agent runs `cat Makefile`, `cat README.md`, or guesses flags | Deterministic tool schema (`tools/list`) |
| **Type Safety** | None (untyped string interpolation) | Strict JSON Schema types (`string`, `int`, defaults) |
| **Context Window Cost** | ~1,800–2,500 tokens of shell exploration | ~80 tokens of tool metadata |
| **Failure Rate** | High (missing env vars, syntax quirks, tab issues) | Near-zero (parameter validation happens before execution) |
| **Tool Calls** | 3 to 6 exploratory calls | 1 atomic call |

```text
Before (Make / Just):
  [tool] cat README.md                         → 950 tokens
  [tool] cat Makefile                          → 620 tokens
  [tool] make test-worker                      → fails (target doesn't exist)
  [tool] make test SERVICE=worker              → passes
  Total: 4 tool calls, ~2,100 tokens consumed

After (run via MCP):
  [tool] mcp:run test(service: "worker")       → passes
  Total: 1 tool call, ~90 tokens consumed
```

---

## Moving Beyond 1976

Make had a magnificent run. Fifty years is an extraordinary innings for a utility written at Bell Labs on a PDP-11. It taught us what dependency graphs look like.

Thibaud is entirely right: for compiled code, modern build systems describe intent far better than Make ever could. And for tasks, pretending that pushing a Docker image or running your test suite is a "file transformation" has caused half a century of unnecessary collective suffering.

`just` proved that developers were crying out for a cleaner syntax. 

The next step is acknowledging that our task runners must be polyglot, typed, and built for both the human at the keyboard and the agent in the loop.

The discovery tax is zero.

```bash
# Cargo
cargo install run

# macOS / Homebrew
brew install nihilok/tap/runtool

# Arch Linux (AUR)
yay -S runtool
```

*Source on GitHub: [github.com/nihilok/run](https://github.com/nihilok/run) • Documentation: [runtool.dev](https://runtool.dev)*
