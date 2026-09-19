---
layout: post
title: "The Silent Ping: How We Built Multi-Agent Slack Orchestration with SQLite and a \"Godfather\" Session"
date: 2026-09-19
---

You kick off a large refactor in Claude Code. It's going to run 300 tests, update 14 files across three packages, and take roughly eight minutes. 

You switch over to Slack or go put the kettle on.

Ten minutes later you wander back to your desk. The terminal hasn't moved. It stalled ninety seconds after you left because it wanted confirmation to run a migration.

Naturally, your first instinct is to automate this: hook up a Slack webhook or a bot token so the agent pings you when it's done or stuck. 

Except you immediately run into the Silent Ping.

## The Silent Ping Problem

If you use your own user token or standard incoming webhooks tied to your user profile, Slack is "helpful": it knows *you* sent the message. 

And Slack does not send desktop banners, sound chimes, or mobile push notifications for messages you send to yourself. You get a little grey text line in your "saved messages" or a private channel, utterly devoid of urgency. You're still babysitting the terminal; you're just doing it through Slack.

The fix was obvious: my agent needed its own legal identity.

Enter **Mike's Agent**.

I created a dedicated Slack app with its own bot token, installed it into our workspace, and called it Mike's Agent. 

Then came the real trick: **I marked Mike's Agent as a "VIP" in Slack.** 

If you haven't used Slack's VIP feature, it's a game changer for agent workflows. VIP messages bypass standard notification throttling and muting. The bot doesn't even need to loudly `@` me in every message (though it can). Anything Mike's Agent posts in our 1:1 App DM lands as an immediate, unmissable notification on my desktop, phone, and watch. 

The ping is no longer silent.

Once that worked, I persuaded a couple of teammates to do the same. Soon we had Sarah's Agent and Dave's Agent in the workspace. But that's when things got interesting — and slightly chaotic.

## The Multi-Session Chaos

It's 2026; nobody runs just one agent session anymore.

On any given morning, I might have three separate Claude Code or Codex sessions open in different tmux panes:
- One is running a slow integration test suite in a detached worktree.
- One is refactoring a database schema.
- One is doing exploratory research on an external API.

If someone in Slack threads a message: *"@Mike's Agent can you rerun that migration with the `--dry-run` flag?"* — which session responds?

If all three sessions are listening to Slack events, you get an instant token wildfire: three LLMs wake up simultaneously, generate three overlapping responses, and race to reply in the same thread.

We needed an orchestrator. But I didn't want a heavy Kafka queue, a Redis cluster, or an over-engineered cloud broker for local terminal sessions.

So I reached for the most reliable piece of infrastructure on Earth: **SQLite**.

## The Daemon and the Database

Here's the architecture that runs locally on my machine:

1. A lightweight Python background daemon listens for Slack events via the Slack Socket Mode API (zero public webhook URLs required, works completely behind NAT and VPNs).
2. Incoming `@Mike's Agent` mentions, thread replies, and emoji reactions are written straight into a local SQLite database (`~/.agents/slack_events.db`).
3. The table schema looks roughly like this:

```sql
CREATE TABLE IF NOT EXISTS slack_events (
    id TEXT PRIMARY KEY,
    channel_id TEXT NOT NULL,
    thread_ts TEXT NOT NULL,
    user_id TEXT NOT NULL,
    text TEXT NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, claimed, completed
    claimed_by TEXT,               -- session UUID
    claimed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

The magic lies in how agent sessions claim work.

Instead of an agent blindly reacting to incoming webhooks, each session periodically inspects the database when it reaches an idle state. To claim an event without race conditions, it executes an atomic SQLite transaction:

```sql
UPDATE slack_events
SET status = 'claimed',
    claimed_by = 'claude-session-8f2a',
    claimed_at = CURRENT_TIMESTAMP
WHERE id = :event_id 
  AND status = 'pending'
RETURNING *;
```

If the query returns a row, that session owns the task. If zero rows return, another session already grabbed it. Fast, atomic, zero lock contention, and entirely local.

## Enter the "Godfather" Session

Most of the time, worker sessions shouldn't be browsing for random tasks. They should be focused on the specific branch or test suite they were invoked for.

To keep order, I run what I call the **Godfather session**.

The Godfather is a persistent, overarching Claude/Codex orchestrator session running in its own dedicated tmux window. It monitors the daemon's activity and acts as the central dispatcher:

```
                  [ Slack Socket Mode ]
                            │
                            ▼
                  [ Local Event Daemon ]
                            │
                            ▼
              ┌───────────────────────────┐
              │    SQLite Event Queue     │
              └───────────────────────────┘
                            │
             (Atomically claims ambient events)
                            │
                            ▼
                 ┌─────────────────────┐
                 │  "Godfather" Agent  │
                 │   (Orchestrator)    │
                 └──────────┬──────────┘
                            │
           ┌────────────────┴────────────────┐
           ▼                                 ▼
   [ Worker Session 1 ]              [ Worker Session 2 ]
   (Integration Tests)               (API Refactoring)
```

1. **Ambient Mentions:** When an unassigned mention comes in from a teammate asking a general question or triggering a workflow, the Godfather claims it atomically.
2. **Context Routing:** If the message relates to an active feature branch, the Godfather routes the job or leaves it for the specific worker session that registered that `thread_ts`.
3. **Response Coordination:** When a background worker finishes, it reports back through the database. Mike's Agent replies in the original Slack thread with the result, diff, or error output.

## Bot-to-Bot Channels: Multi-Day Autonomous Runs

The 1:1 App DM with Mike's Agent is my personal cockpit. But the real breakthrough happened when we put our bots into shared channels together.

We created dedicated project channels where the humans rarely type, but **Mike's Agent**, **Sarah's Agent**, and **Dave's Agent** live side-by-side.

This unlocked multi-day autonomous workflows:

Instead of babysitting a long migration, my **Godfather session can drive work autonomously for days at a time**. 

When Mike's Agent finishes generating updated database bindings, it doesn't wait for me to ping Sarah. It posts an update into `#bot-migrations`:
> *"Mike's Agent: Schema migration `0043_orders` complete on branch `feat/orders-v2`. Artifacts pushed."*

Sarah's Agent—listening via her local daemon—picks up the event, claims it, runs the frontend integration tests against that branch, and replies in the thread:
> *"Sarah's Agent: Contract tests passed. 2 warnings in `useOrders.ts`. Output logged."*

All of this happens while Sarah and I are asleep, reviewing PRs, or working on entirely different projects. No human serving as a biological copy-paste relay between two terminal windows.

And if something goes sideways? Mike's Agent posts to my 1:1 DM. Because it's a VIP contact, my phone buzzes immediately.

## The Takeaway

We spend so much time talking about "autonomous agent swarms" in the abstract, but the real bottlenecks are mundane developer ergonomics:

1. **Kill the Silent Ping:** Give your agent its own bot identity and mark it as a Slack **VIP** so priority notifications always break through without `@mention` fatigue.
2. **Local Atomic State:** You don't need a heavy broker. A simple local SQLite table with atomic `UPDATE ... RETURNING` handles multi-session concurrency cleanly.
3. **The Godfather Pattern:** Use one high-level orchestrator session to triage and coordinate, while worker sessions focus on their local worktrees.
4. **Bot-to-Bot Channels:** Put your bots in channels together. Let them coordinate handoffs asynchronously so multi-day initiatives actually finish without you micromanaging the terminal.

Give your agent a name. Let it ping you like a real colleague. Your context window — and your kettle — will thank you.
