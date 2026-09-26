---
date: 2026-09-26
layout: post
title: "The Silent Ping: How We Built Multi-Agent Slack Orchestration with SQLite and a \"Godfather\" Session"
---

You kick off a large refactor in Claude Code. It's going to run 300 tests, update 14 files across three packages, and take roughly eight minutes. 

You switch over to Slack or go put the kettle on.

Ten minutes later you wander back to your desk. The terminal hasn't moved. It stalled ninety seconds after you left because it wanted confirmation to run a migration.

Naturally, your first instinct is to automate this: hook up a Slack webhook or a bot token so the agent pings you when it's done or stuck. 

Except you immediately run into the Silent Ping.

---

## The Silent Ping Problem

If you use your own user token or standard incoming webhooks tied to your user profile, Slack is "helpful": it knows *you* sent the message. 

And Slack does not send desktop banners, sound chimes, or mobile push notifications for messages you send to yourself. You get a little grey text line in your "saved messages" or a private channel, utterly devoid of urgency. You're still babysitting the terminal; you're just doing it through Slack.

The fix was obvious: my agent needed its own legal identity.

Enter **Mike's Agent**.

I created a dedicated Slack app with its own bot token, installed it into our workspace, and called it Mike's Agent. 

Then came the real trick: **I marked Mike's Agent as a "VIP" in Slack.** 

If you haven't used Slack's VIP feature, it's a game changer for agent workflows. VIP messages bypass standard notification throttling and muting. The bot doesn't even need to loudly `@` me in every message (though it can). Anything Mike's Agent posts in our 1:1 App DM lands as an immediate, unmissable notification on my desktop, phone, and watch. 

And in that 1:1 App DM, there’s an important operational bonus: *every* message I send to the bot is implicitly addressed to it. No awkward `<@Mike's Agent>` syntax required. In public channels, it listens for its mention; in our private DM, it knows I’m talking directly to it.

The ping is no longer silent.

Once that worked, I persuaded a couple of teammates to do the same. Soon we had Sarah's Agent and Dave's Agent in the workspace. But that's when things got interesting — and slightly chaotic.

---

## The Multi-Session Chaos and the Rate Limit Wall

It's 2026; nobody runs just one agent session anymore.

On any given morning, I might have three separate Claude Code or Codex sessions open in different tmux panes:
- One is running a slow integration test suite in a detached worktree.
- One is refactoring a database schema.
- One is doing exploratory research on an external API.

If all three sessions talk to Slack directly, two disasters strike immediately:

1. **The Rate Limit Wall:** If three local sessions each start polling Slack's `conversations.history` or opening parallel WebSockets, you get slammed with HTTP 429 rate limit bans before lunch.
2. **The Token Wildfire:** If someone in Slack threads a message: *"@Mike's Agent can you rerun that migration with the `--dry-run` flag?"* — which session answers? If all three are listening, three LLMs wake up simultaneously, burn thousands of context tokens generating overlapping responses, and race to reply in the same thread.

We needed an orchestrator. But I didn't want a heavy Kafka queue, a Redis cluster, ngrok tunnels, or an over-engineered cloud broker for local terminal sessions.

So I reached for the most reliable piece of infrastructure on Earth: **SQLite**, backed by a single host-wide daemon.

---

## The Host Daemon and the Local SQLite Engine

Instead of each terminal session fumbling with Slack tokens and hitting API endpoints, we decoupled the architecture into two layers:

```
                  [ Slack Web API ]
                          │
         (Single host-wide polling connection)
                          │
                          ▼
            [ Local Host Daemon (launchd/systemd) ]
                          │
            (Writes diffs & buffers events)
                          │
                          ▼
             ┌─────────────────────────┐
             │   ~/.claude/state/      │
             │     slack-sync.db       │
             │  (SQLite Local State)   │
             └─────────────────────────┘
                          │
           (Zero-overhead local watch streams)
                          │
         ┌────────────────┴────────────────┐
         ▼                                 ▼
 [ Godfather Session ]             [ Worker Session ]
  (Lead Orchestrator)               (Focused Task)
```

1. **A Single Host Daemon:** Managed by `launchd` on macOS or a `systemd` user unit on Linux. It runs in the background, authenticated securely via the Slack CLI (`slack api ... --app <id>`), keeping tokens out of plaintext environment variables. It acts as our rate-limit shield, sweeping channels and DMs on a disciplined cadence.
2. **Local SQLite State (`~/.claude/state/slack-sync.db`):** The daemon diffs conversation history locally. Incoming replies, reactions, and `@mentions` are written straight into normalized local tables:
   - `tracked_messages`: Outbound messages waiting on human input.
   - `seen_reactions` & `seen_replies`: The local diff engine that isolates what is strictly *new*.
   - `mentions`: Inbound requests from humans or other bots.
   - `sessions`: Heartbeat tracking of active terminal sessions.
   - `poll_events`: An event queue drained by active sessions without touching Slack.

---

## Outbound Approval Gates vs. Ambient Watching

When an agent needs human input, it doesn't just spew text into a channel. It uses structured modes:

```bash
# Post an approval gate to the operator's DM
slack_sync post --mode gate \
  --text "Deploying migration 0043_orders to staging — ✅ approve, ❌ hold" \
  --purpose "approve migration 0043"
```

In `--mode gate`, the engine explicitly parses reaction semantics:
* `:white_check_mark:` or `:+1:` → **Approved**
* `:x:` or `:-1:` → **Rejected**
* Thread reply → **Replied**

The agent posts once, receives a unique tracking ID in SQLite, and yields.

---

## Why the Monitored Daemon is Orders of Magnitude More Context-Efficient

The biggest silent failure mode in agentic workflows is letting the LLM manage its own polling logic.

In a conventional setup (or when an agent relies on direct Slack MCP tools like `slack_read_thread`), waiting for a human approval looks like this:

1. The agent calls `slack_read_thread` → dumps 1,500 tokens of raw JSON, timestamps, Block Kit schemas, and full conversation history straight into its context window.
2. The agent parses the payload: *"No reaction or reply detected yet."*
3. The agent initiates a manual polling turn (a `sleep 60` command or a scheduled wakeup).
4. The agent wakes up, executes `slack_read_thread` again → dumps another 1,500 tokens of duplicate thread history.

If you step away from your desk for ten minutes to put the kettle on and the agent checks every sixty seconds, that's **ten tool calls and 15,000+ tokens of redundant Slack payload sludge** permanently baked into your active context window before any decision has even been made.

You hit context compression prematurely. Your agent starts hedging, second-guessing its plan, and losing earlier instructions. And you burn API tokens merely to watch paint dry.

The monitored daemon completely inverts this paradigm.

Instead of the LLM polling Slack, the agent delegates the waiting to Claude Code's native `Monitor` background tool:

```text
Monitor(command="slack_sync --session <SID> watch --ids 7",
        description="Waiting for approval on migration 0043", 
        timeout_ms=1800000)
```

The `watch` command sits quietly in the background outside the LLM's conversation history, tailing the local SQLite `poll_events` table. 

There are **zero Slack API calls** executed by the agent. There is **zero manual polling logic** cluttering the conversation. While waiting, the context cost is literally **zero tokens**.

The moment I tap `:white_check_mark:` on my phone:
1. The host daemon records the reaction in SQLite during its background sweep.
2. The local `watch` process computes the diff and emits a single, surgical JSON line to stdout:
   ```json
   {"event":"slack-sync", "id":7, "summary":"APPROVED by U0123 via :white_check_mark:", "resolution":{"kind":"approved"}}
   ```
3. The `Monitor` tool catches that stdout line and triggers an immediate reactive notification into the agent's context.

Total tokens consumed across that entire ten-minute wait: **~40 tokens** (just the final resolution event). 

Removing repeated integration calls and manual polling isn't just a minor optimisation — it is **orders of magnitude** more context-efficient.


---

## Concurrency and Atomic Claims

What about inbound mentions? If someone asks a question in a public channel, how do we prevent three tmux panes from racing to answer?

Mentions land in the `mentions` table in an `unclaimed` state. When a session is ready for ambient work, it executes an atomic SQLite transaction:

```sql
UPDATE mentions
SET status = 'claimed',
    claimed_by = :session_id,
    claimed_at = CURRENT_TIMESTAMP
WHERE id = :mention_id 
  AND status = 'unclaimed'
RETURNING *;
```

If the query returns a row, that specific terminal session owns the task. If zero rows return, another session grabbed it a microsecond earlier. Fast, atomic, zero lock contention.

And if a mention goes completely unheeded? The database enforces a **120-second grace fallback**: if an event sits unclaimed, it is automatically routed to the oldest live session recorded in the `sessions` table.

---

## Enter the "Godfather" Session

Most of the time, individual worker sessions shouldn't be browsing for random tasks. They should remain strictly focused on the feature branch or failing test suite they were invoked to solve.

To maintain discipline, I run what I call the **Godfather session** (our lead orchestrator).

The Godfather is an overarching Claude/Codex session running in a persistent tmux window. It doesn't write low-level code directly. Instead, it acts as the project manager:
* It claims unassigned ambient mentions from teammates.
* It breaks large goals into bounded sub-packages and delegates them to worker sessions running in detached worktrees.
* It monitors approval gates and routes responses back to the original Slack threads.

---

## Bot-to-Bot Channels: Multi-Day Autonomous Runs

The 1:1 App DM with Mike's Agent is my personal cockpit. But the real breakthrough happened when we put our bots into shared channels together.

We created dedicated project channels where humans rarely type, but **Mike's Agent**, **Sarah's Agent**, and **Dave's Agent** live side-by-side.

This unlocked multi-day autonomous workflows:

Instead of babysitting a long migration, my **Godfather session can drive work autonomously across entire weekends**. 

When Mike's Agent finishes generating updated database bindings, it doesn't wait for me to ping Sarah. It posts an update into `#bot-migrations`:
> *"Mike's Agent: Schema migration `0043_orders` complete on branch `feat/orders-v2`. Artifacts pushed."*

Sarah's Agent—listening via her local daemon—picks up the event, claims it atomically, runs the frontend integration tests against that branch, and replies in the thread:
> *"Sarah's Agent: Contract tests passed. 2 warnings in `useOrders.ts`. Output logged."*

All of this happens while Sarah and I are asleep, reviewing PRs, or working on entirely different projects. No human serving as a biological copy-paste relay between two terminal windows.

And if something goes sideways? Mike's Agent posts to my 1:1 DM. Because it's a VIP contact, my phone buzzes immediately.

---

## The Maths

| Architecture | Context Burn (10-min wait) | Slack Tool Calls in Session | Notification Reliability | Concurrency & Rate Limits |
|---|---|---|---|---|
| **Direct Slack MCP / API Polling** | ~15,000–30,000 tokens (repeating thread dumps) | 10+ calls (manual sleep/wake loop) | ❌ Silent or throttled | Rapid HTTP 429 rate-limit risk |
| **Heavy Cloud Broker** (Kafka / Redis) | ~2,000–5,000 tokens (broker handshakes) | Multiple polling turns | ⚠️ Standard (throttled unless VIP) | Complex distributed locks; cloud bill |
| **Host Daemon + SQLite `Monitor`** | **~40 tokens** (only the final resolution diff) | **0 calls** (1 background watch process) | ✅ Unmissable (VIP bypasses throttles) | ✅ Atomic (`UPDATE ... RETURNING`); zero 429s |


---

## The Takeaway

We spend so much time talking about "autonomous agent swarms" in the abstract, but the real bottlenecks are mundane developer ergonomics:

1. **Kill the Silent Ping:** Give your agent its own bot identity and mark it as a Slack **VIP** so priority notifications always break through without `@mention` fatigue.
2. **Decouple with a Host Daemon:** Don't let raw agent sessions hit Slack directly. A single host daemon protects your team from 429 rate limit bans and manages authentication cleanly.
3. **Reactive Streaming over Polling:** Never let an agent sleep in a loop. Pair a local SQLite queue with background monitoring tools so events trigger zero-token wakeups.
4. **Local Atomic State:** A simple local SQLite table with atomic `UPDATE ... RETURNING` and session heartbeats handles multi-agent concurrency without cloud dependencies.
5. **The Godfather Pattern:** Use one high-level orchestrator session to triage and coordinate, while worker sessions focus on their local worktrees.

Give your agent a name. Let it ping you like a real colleague. Your context window — and your kettle — will thank you.
