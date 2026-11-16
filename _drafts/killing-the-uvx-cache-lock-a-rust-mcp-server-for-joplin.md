---
layout: post
title: "Killing the uvx Cache Lock: A Rust MCP Server for Joplin"
---

You open three terminal panes to run three concurrent agent sessions. Each session boots its configured MCP servers over `stdio`. Two seconds later, two of them are wedged waiting on the `uv` cache lock while the third spends a second and a half warming up a Python interpreter just to read a note from localhost.

If you run a single agent at a time, `uvx` is lovely. The moment you run parallel sessions across Claude Code, Codex, and Antigravity (`agy`), every new session spawns its own `uvx` wrapper, contends on the same shared cache, and pays the Python startup tax before a single JSON-RPC byte crosses the wire.

On macOS, we had worked around it by running a shared `launchd` HTTP MCP server on port `8766` so multiple sessions could talk to one long-lived Python process. It stopped the lock contention, at the cost of yet another daemon to keep alive, another port to manage, and another config divergence between machines.

The cleaner fix was obvious: stop wrapping a localhost HTTP API in a Python runtime at all.

Enter **[joplin-mcp](https://github.com/nihilok/joplin-mcp)**: a standalone, zero-runtime-dependency Rust MCP server for Joplin's local Web Clipper / Data API.

---

## 1. The `uvx` Cache Stampede

`uv` and `uvx` are brilliant tools for Python packaging. Nobody misses managing `virtualenv` paths by hand.

But `stdio` MCP servers have an awkward lifecycle: **the client spawns a fresh server process for every single session.** That works fine when the binary starts in two milliseconds and touches nothing on disk. When the "command" is actually a package runner resolving environments and locking a shared cache directory, parallel agent workflows hit a wall:

1. **Cache lock contention:** Three panes spawning `uvx` simultaneously race on the `uv` cache lock. Two sit blocked waiting for the first to finish checking metadata.
2. **Cold-start overhead:** Every new session pays Python interpreter startup and import time before answering `initialize`.
3. **Daemon drift:** Moving to a shared `launchd` or `systemd` HTTP server on port `8766` solves the lock, but now you have a stateful background service instead of simple `stdio` plumbing.

I'd already seen how clean a single compiled binary feels with [`run`](https://github.com/nihilok/run)'s `--serve-mcp` flag: drop one static binary in `~/.local/bin`, point the MCP config at it, and forget it exists. With `joplin-mcp`, I took that same pattern and made `stdio` MCP the entire binary.

Your MCP config collapses to four lines with zero arguments:

```json
{
  "mcpServers": {
    "joplin-mcp": {
      "command": "joplin-mcp"
    }
  }
}
```

---

## 2. Zero-Config Profile Auto-Discovery

A good local CLI tool shouldn't force you to copy-paste API tokens into every machine's `~/.claude.json` or agent config just to talk to localhost.

When `JOPLIN_TOKEN` (and `JOPLIN_API_TOKEN`) is unset, `joplin-mcp` automatically probes your local Joplin profiles in priority order:

1. **Joplin Desktop first** (default port `41184`): preferred when open because Desktop syncs faster through the Web Clipper service.
2. **`joplin-cli` second** (`~/.config/joplin/settings.json`, e.g. port `41185` running under a `systemd` user service): automatic fallback when Desktop is closed.

The client probes `/folders?limit=1` with a two-second timeout, finds the active listener, and caches the resolved endpoint in memory. Even better: **if a request fails because you closed Joplin Desktop and fell back to `joplin-cli` (or vice versa), `joplin-mcp` invalidates its cached endpoint and re-probes on the next call.** No restarting your agent session just because you closed a window.

### Keeping Tokens Out of Plaintext Configs

If you do pass an explicit token (for instance, talking to a specific port or remote tunnel), you still don't have to leave secrets sitting in plaintext JSON files. Passing `--token-cmd` (or `JOPLIN_TOKEN_CMD`) runs a shell command and reads the token from `stdout`:

```json
{
  "mcpServers": {
    "joplin-mcp": {
      "command": "joplin-mcp",
      "env": {
        "JOPLIN_TOKEN_CMD": "security find-generic-password -a joplin -s joplin-web-clipper -w"
      }
    }
  }
}
```

---

## 3. Safety by Default, Strict by Design

Giving an autonomous coding agent access to your personal knowledge base is only comfortable if the blast radius is bounded.

Out of the box, `joplin-mcp` exposes **22 tools** covering `ping`, notebooks (`list_notebooks`, `create_notebook`, `update_notebook`), notes (`get_note`, `get_note_resources`, `get_links`, `create_note`, `update_note`, `edit_note`, `find_notes`, `find_in_note`, `find_notes_with_tag`, `find_notes_in_notebook`, `get_all_notes`), tags (`list_tags`, `create_tag`, `update_tag`, `get_tags_by_note`, `tag_note`, `untag_note`), and `restore_from_trash`.

Notice what is missing from that list: **deletes.**

`delete_note`, `delete_notebook`, and `delete_tag` are omitted from `tools/list` and rejected on `tools/call` unless you explicitly opt in with `--allow-delete` or `JOPLIN_ALLOW_DELETE=true`. An agent can organise, edit, and even restore from trash, without ever having permission to wipe a notebook on a bad prompt.

Under the hood, the entire binary stays lean:

* **Five crates:** `clap`, `regex`, `serde`, `serde_json`, and `ureq`. No async runtime, no Tokio thread pools, no heavy dependency tree.
* **Strict MCP handshake:** Negotiates `protocolVersion` (`2024-11-05`) cleanly over `stdio` JSON-RPC 2.0.

---

## 4. Why It Came Together in One Session

The entire initial build landed cleanly in a single session, and the biggest reason wasn't clever prompting: it was putting strict Rust guardrails in place **from the very first prompt**, before a single line of application code existed.

`Cargo.toml` sets `clippy::pedantic` and denies both `unwrap_used` and `expect_used`. A git pre-commit hook enforces `cargo fmt --all -- --check`, `cargo clippy --all-targets -- -D warnings`, and `cargo test` on every commit.

When you make the compiler and linter that unforgiving from commit zero, the agent cannot accumulate debt:

* **No sloppy error paths:** Denying `.unwrap()` and `.expect()` forces proper `Result` propagation across every HTTP call, JSON parse, and `stdio` read from the start.
* **No argument bloat:** `clippy::pedantic` flags sprawling parameter lists (`too_many_arguments`) immediately, pushing the design towards clean option structs instead of 10-argument helper functions.
* **Immediate edge-case feedback:** Rather than refactoring a messy prototype at the end, formatting, warnings, and test failures are caught at every single commit boundary.

---

## 5. Before and After

```text
Before (uvx + workaround):
  Session 1: uvx joplin-mcp-server   -> acquires uv cache lock, boots Python (~1.2s)
  Session 2: uvx joplin-mcp-server   -> blocks on uv cache lock
  macOS fix: launchd HTTP daemon     -> extra plist, port 8766, separate config

After (joplin-mcp in Rust):
  Session 1: joplin-mcp              -> instant binary start, auto-discovers 41184/41185
  Session 2: joplin-mcp              -> instant binary start, zero shared locks
  Session 3: joplin-mcp              -> instant binary start, zero daemons to babysit
```

No package runner contention. No Python runtime in the hot path. No hardcoded API tokens in `~/.claude.json`. Just one binary that starts immediately and stays out of the way.

```sh
git clone https://github.com/nihilok/joplin-mcp
cd joplin-mcp && cargo install --path .
```
