---
layout: post
title: "The Hype Horizon"
---

The cycle at work is completely predictable: the team endlessly flip-flops between AI tools.

One week, everyone is fed up with Claude Code. The complaints are always identical: *"It’s too verbose, it stops too often, and it asks three clarifying questions before it touches a single file."* 

So everyone drifts over to Codex. Two days later, the mood inverts: *"Codex is wonderfully concise, but it’s completely hopeless if you leave it running overnight—it hit a trivial question at 2:00 AM, stopped dead, and waited six hours for me to type 'yes'."*

Then a fresh checkpoint drops. Anthropic releases Opus 5.5 and it suddenly shuts up and gets to the point. OpenAI ships GPT-6 and it finally stops stalling out in the middle of the night. The quirks swap places, the complaints reset, and the entire office rotates their preferences all over again.

Watching this cycle, I realised early on that picking a favourite model is a fool's errand. Their personalities fluctuate with every minor version bump.

Instead, I treat both platforms with complete, cold agnosticism. In fact, I gamify it: **can I be the most productive engineer on the team while generating the least extra spend?**

---

## 1. Gamifying the Workday

At the office, I use Claude Code as a "Godfather" session—a lead orchestrator running in a persistent terminal from whence I dispatch workers across both Claude and Codex. 

I don't care which one is currently in vogue on Reddit. I care about quota arithmetic:

* Claude starts getting chatty or burning through tokens on exploratory reasoning? I offload the heavy execution to Codex.
* Codex gets stubborn on an ambiguous edge case or stalls? I route the task straight back to Claude.
* A long build or migration needs to run overnight? I pick the model that’s currently less inclined to go to sleep waiting for human reassurance.

The game is simple: stay strictly within our base subscription usage across the two platforms, never pay a penny in overage, never hit a 5-hour rate-limit timeout, and keep pull requests shipping. 

By treating the models like interchangeable Unix pipes rather than lifestyle choices, you stop caring about their week-to-week mood swings.

And then I go home.

---

## 2. The Freight Train Outside the Bubble

At home, for my personal projects on my Arch Linux rig, I don't touch Claude Code. I don't touch Codex. 

I use `agy`—the Gemini / Antigravity CLI—purely because it comes bundled with my personal Google AI Pro plan.

If your perception of AI tooling is formed entirely by developer Twitter and technical subreddits, you’d assume the universe begins and ends with Anthropic and OpenAI. Outside of official announcements, `agy` barely registers in the social media hype cycle. There are no breathless threads dissecting its system prompts; there are no viral memes about its latest UI tweak. It sits completely beyond the hype horizon.

Yet in practice, it has been an absolute freight train.

On a single standard subscription account, I have never once hit a quota wall. I have never had to ration tokens. I have never had to play context-window Tetris or babysit a 429 rate limit. 

While the work bubble is endlessly fretting over token pricing and prompt verbosity, `agy` has smashed through massive, complex projects in minutes:

* **[AgentTelegramBot](https://github.com/nihilok/AgentTelegramBot):** A complete, multi-threaded Rust and Teloxide daemon with a local SQLite IPC server that routes live agent alerts to my phone with swipe-to-reply session steering.
* **[Spud](https://github.com/nihilok/spud):** A modular, local-first voice dictation and orchestration platform integrating `faster-whisper` and `Qwen3-TTS` on my RTX 5060 Ti directly into terminal multiplexer panes.
* Converting my base EndeavourOS installation into a completely bespoke, agent-centric Hyprland operating system—rebuilding keybindings, scripts, and window rules in minutes without missing a beat.

No hesitation. No twenty-question questionnaires before executing a shell command. It just chewed through the tasks and shipped.

And that was when the real contrast hit me: **the hype machine has created an echo chamber where developers tolerate constant friction simply because they don't realise what's happening outside the perimeter.**

---

## 3. The Real Multiplier: The Pilot, Not the Plane

When you step back and look at the whole picture—juggling Claude and Codex at the office, smashing out Rust daemons with `agy` at home—the central truth becomes undeniable:

**It was never the tool that made the difference. It was the operator.**

In 2026, all frontier agents are astonishingly capable. They all run bash commands, call tools, inspect files, and edit code. The benchmark differences on paper are single-digit margins that flip every time someone pushes a new checkpoint to production.

What actually dictates whether an agent ships clean software or drowns in hallucinations isn't the model's logo. It’s the human's systems discipline:

### A. Saving Tokens with Actual Skills (Neovim)
I don’t sit in Neovim writing endless boilerplate by hand anymore. But Neovim remains open in a split terminal for one crucial reason: **saving tokens by using my own actual skills.**

Inside the hype bubble, developers treat their agent like an all-knowing oracle for trivial navigation:
*"Can you search the repo for where `process_order` is called?"*
*"Can you check which interface defines `PaymentMethod`?"*

The agent fires off three tool calls, reads four files, dumps 3,000 tokens of file sludge into its context window, and burns your quota just to tell you what's on line 42 of a file you already know.

Instead of paying that token tax, I pop open Neovim in a quick split. Two keystrokes in Telescope or an LSP shortcut, and my own muscle memory finds the definition, verifies the import, or checks the diff in two seconds flat. 

You don't burn precious context asking an LLM questions that your own skills can answer instantly. You keep the agent’s context lean, clean, and pointed strictly at the heavy lifting.

### B. Demystifying the Binary (Shell Muscle)
Inside the bubble, launching an agent is treated like entering a cathedral: opening a dedicated desktop suite, clicking through workspace modals, or typing out paragraphs of setup instructions.

In a sovereign shell, an agent is just another binary in your `$PATH`. 

A two-letter shell alias like `asb` drops me straight into `~/sandbox` and spins up `agy` in half a second. Another alias launches an agent with raw execution flags. It sits right alongside `alias v='nvim .'` and `alias g='git'`. 

The moment you treat an agent like a standard Unix binary in your terminal, the marketing mystique evaporates.

### C. Workspace Orchestration (Herdr & SSH)
To keep all these pieces coherent without relying on a vendor's proprietary desktop wrapper, I run a terminal workspace manager called [Herdr](https://herdr.dev).

```
┌────────────────────────────────────────────────────────┐
│ HERDR WORKSPACE                                        │
│                                                        │
│  [Tab 1: Mac / Local]       [Tab 2: Arch / SSH]        │
│  ┌───────────────────────┐  ┌───────────────────────┐  │
│  │ Neovim (Inspection)   │  │ Antigravity (Gemini)  │  │
│  │ LSP / Diff Search     │  │ Fast Heavy Scaffolding │  │
│  └───────────────────────┘  └───────────────────────┘  │
│  ┌───────────────────────┐  ┌───────────────────────┐  │
│  │ Claude Code (Worker)  │  │ Codex (Worker)        │  │
│  │ Surgical Bash Loop    │  │ Test & Edge Cases     │  │
│  └───────────────────────┘  └───────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

My lightweight MacBook on the sofa connects over SSH to the Arch Linux workstation in the corner chewing through heavy local compilation and voice models. Herdr keeps the persistent sessions alive, the hotkeys consistent, and the status indicators (`working`, `idle`, `blocked`) visible across machines.

The environment belongs to me, not to Anthropic, OpenAI, or Google.

---

## 4. The Takeaway

The AI industry spends billions of dollars trying to convince you that productivity is something you rent on a monthly subscription. 

If you believe the marketing, you'll spend your days riding the hype rollercoaster: celebrating when your chosen tool gets a minor version bump, despairing when it gets too verbose, and endlessly debating which platform has "won" the week.

Step outside the horizon.

Treat the models with cold, unemotional agnosticism. Gamify your subscriptions. Use your own developer skills in Neovim to keep their contexts clean. And don't sleep on the quiet workhorses outside the hype cycle that simply show up, don't ask twenty timid questions, and smash through work.

The models will change their personalities again next Tuesday. The engineer at the terminal is still the one building the system.
