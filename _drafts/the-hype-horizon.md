---
layout: post
title: "The Hype Horizon"
---

By 10:30 on a Monday morning, our internal `#dev-tools` Slack channel had devolved into tribal warfare.

On one side were the Claude Code loyalists. They were sharing terminal prompt snippets, swapping Reddit threads, and arguing that Anthropic’s CLI was the only tool built with genuine aesthetic taste. On the other side was the Codex faction, defending OpenAI’s reasoning models, quoting benchmark leaderboards, and citing enterprise compliance agreements.

Both sides were entirely convinced that the other camp was fumbling in the dark with a second-rate toy.

I sat there watching the notifications roll in, glancing between my Slack window and my terminal, thinking about what I’d done the night before.

On Sunday evening, sitting at home on my Arch Linux workstation, I’d spent three hours building, testing, and shipping an entire subsystem across multiple packages. I hadn’t touched Claude Code. I hadn’t touched Codex. I’d used Antigravity—the Gemini CLI—purely because it came bundled with my personal Google subscription.

If your entire world is shaped by developer Twitter and technical subreddits, Antigravity barely exists. There are no breathless viral demo videos every forty-eight hours. There are no cult Discord servers arguing over the sacred wording of markdown system prompts. It sits completely beyond the radar of the mainstream zeitgeist.

Yet in three hours, it had torn through tasks, run tests, and refactored code with zero drama.

And that was when the penny dropped: we haven’t just built better developer tools in 2026. We’ve built **The Hype Horizon**—and trapped ourselves inside it.

---

## 1. The Geometry of the Bubble

The Hype Horizon is the invisible perimeter drawn around our engineering habits by social media algorithms, enterprise procurement, and community echo chambers.

It operates in three concentric rings:

1. **The Algorithmic Ring:** Your Twitter feed and Reddit front page are tuned to amplify the loudest voices. The venture-backed startups and hyper-active developer communities dominate the discourse. If an agent isn’t generating memes or weekly controversy, the algorithm treats it as non-existent.
2. **The Procurement Ring:** At the office, tooling choices are governed by enterprise agreements and legal sign-offs. "Nobody gets fired for buying Claude or Codex." The entire engineering department orientates its internal scripts, CI pipelines, and mental models around the approved vendors.
3. **The Sunk-Cost Ring:** You spend forty hours fine-tuning your `.rules` file, memorising keyboard shortcuts, and learning an agent’s specific idiosyncrasies. Naturally, you develop an emotional investment in it being the best.

Once you’re inside the horizon, a strange cognitive distortion takes hold: **you mistake the boundaries of your tool for the boundaries of artificial intelligence.**

If your agent chokes on a long-running subprocess, you assume models can't handle long horizons. If your agent hallucinates an import, you assume the language is too ambiguous. And if another agent is mentioned, you dismiss it out of hand because it isn't part of your tribe's accepted canon.

---

## 2. Projecting the Wizard onto the Wand

The deepest trap of the Hype Horizon isn’t just that we dismiss other tools. It’s that **we project our own competence onto the tool we happen to be using.**

When a complex refactor goes smoothly in Claude Code, the bubble tells us: *"Claude is an absolute genius."*

We don’t say: *"I broke that ambiguous feature down into three tightly scoped tasks, isolated the changes in a clean branch, caught the subtle logic regression with a unit test, and corrected the import before it hit git."*

Because we attribute our success entirely to the model, we convince ourselves that the tool is doing the heavy lifting. We treat the agent like a magical talisman. We assume that if we were to step outside our chosen ecosystem, our productivity would instantly evaporate.

That’s the illusion.

When you step outside the bubble and pick up an agent with zero hype—an agent you’re using merely because it happened to be on your billing invoice—the illusion shatters. You realise that you are just as fast, just as disciplined, and just as productive.

The frontier models in 2026—Claude, Codex, Gemini, and the top-tier open-weights—are all astonishingly capable. They all have tool-calling loops, terminal execution, and code editing. The variance between them on public benchmarks is single-digit percentages.

The variance between how two different engineers drive them is a thousand percent.

It was never the tool that made the difference. It was you.

---

## 3. The Anatomy of Real Leverage

If the magic isn't in the model branding, where is it?

It’s in the unglamorous, durable systems engineering that surrounds the agent. It’s the harness, the workspace hygiene, and the human verification loop.

Here is what actual leverage looks like in practice, regardless of whether you're typing into Claude, Codex, or Antigravity:

### A. The Sovereign Inspection Deck (Neovim & Shell Muscle)
I don’t sit in Neovim all day writing boilerplate by hand anymore. But Neovim is indispensable for one vital reason: **saving tokens by using my own actual skills.**

Inside the hype bubble, developers treat their agent like an all-knowing oracle for trivial navigation:
*"Can you search the repo for where `process_order` is called?"*
*"Can you check which interface defines `PaymentMethod`?"*

The agent fires off three tool calls, reads four files, dumps 2,500 tokens of file sludge into its context window, and charges you against your rate limit just to tell you what's on line 42 of a file you already know.

Instead of paying that token tax, I pop open Neovim in a quick split or scratch terminal. Two keystrokes in Telescope or an LSP shortcut, and I’ve inspected the definition, verified the import, or checked the diff in two seconds flat. 

The same discipline applies to shell choreography. Inside the bubble, launching an agent is treated like entering a cathedral: opening a dedicated desktop suite, clicking through workspace modals, or prompting the bot to prepare a scratch directory. In a sovereign terminal, an agent is just another binary in your PATH. A two-letter shell alias like `asb` jumps into a sandbox and fires up the model in half a second, sitting right alongside `alias v='nvim .'`.

You don’t burn precious context asking an LLM questions that your own muscle memory can answer instantly. You keep the agent’s context lean, clean, and pointed strictly at the heavy lifting.

### B. Workspace Orchestration (Herdr & SSH)
Instead of relying on a vendor’s proprietary desktop GUI, I use a terminal workspace manager called [Herdr](https://herdr.dev) paired with persistent sessions and SSH.

```
┌────────────────────────────────────────────────────────┐
│ HERDR WORKSPACE                                        │
│                                                        │
│  [Tab 1: Mac / Local]       [Tab 2: Arch / SSH]        │
│  ┌───────────────────────┐  ┌───────────────────────┐  │
│  │ Neovim (Inspection)   │  │ Antigravity (Gemini)  │  │
│  │ LSP / Diff Review     │  │ Big Context / Scaff   │  │
│  └───────────────────────┘  └───────────────────────┘  │
│  ┌───────────────────────┐  ┌───────────────────────┐  │
│  │ Claude Code (Worker)  │  │ Codex (Worker)        │  │
│  │ Surgical Bash Loop    │  │ Test Synthesis        │  │
│  └───────────────────────┘  └───────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

My lightweight MacBook on the sofa connects over SSH to a headless Arch Linux box in the corner chewing through heavy compilation and test runs. Herdr gives me unified session management, hotkeys, and status indicators (`working`, `idle`, `blocked`) across machines.

The environment is decoupled from any single AI vendor.

### C. The Mothership Pattern
At work, I don't use Claude Code as a standalone assistant. I use it as an orchestrator—a **"Godfather" session** running in a primary workspace from whence I dispatch focused worker sessions across both Claude and Codex.

The Godfather acts as the project lead: breaking down the roadmap, assigning discrete tasks to worker sessions in separate worktrees, and coordinating progress.

At home, I apply the exact same mental model to Antigravity. The architectural discipline—orchestration, task scoping, independent execution—is identical. The agents are interchangeable worker processes.

---

## 4. The Takeaway

There is immense commercial pressure to turn developers into brand evangelists. Silicon Valley wants you to believe that your engineering capability is an annuity you lease from an AI lab for twenty dollars a month.

It isn’t.

Claude Code is brilliant. Codex is brilliant. Antigravity is brilliant. If you have the discipline, you can build great software with any of them. If you lack the discipline, all three will happily hallucinate you into a ditch.

Stop arguing in Slack about which wand is the most magical. Stop letting social media hype dictate your tooling perimeter.

The agent is just a subprocess. Your workspace belongs to you. And the engineer in the chair is still the one building the system.
