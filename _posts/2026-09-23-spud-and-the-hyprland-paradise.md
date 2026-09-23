---
date: 2026-09-23
layout: post
title: "The Biological Relay: How Spud and Gemini Turned Hyprland into an AI Poweruser Paradise"
---

Hold `Super + D`. Say `kubectl get pods -n ingress-nginx`. Release. 

Spotify drops to half volume, the command appears letter-by-letter at the cursor in Ghostty, and the music snaps straight back to 100%. Total time elapsed: 420 milliseconds.

No typing. No pausing the music. No reaching for the mouse.

If you’d told me two years ago that my daily desktop would handle push-to-talk terminal dictation, auto-duck my audio streams, talk back in a cloned copy of my own voice, and pair with an AI that writes its own window manager hotkeys on the fly, I’d have asked what unholy PPA cocktail you’d been drinking.

Yet here we are. It runs on `shpadoinkle-1` (my main workstation, named in honour of *Cannibal! The Musical* — *"My heart's as full as a baked potato"*), and it came together in a single afternoon.

---

## 1. The Distro Graveyard

Before `shpadoinkle-1` found peace, my NVMe drive was a revolving graveyard of operating systems I genuinely tried to daily-drive:

1. **Debian** — Solid as granite, and roughly three geological epochs behind on Wayland compositors.
2. **Ubuntu** — Fine until release upgrades shattered custom PPAs and Snaps hijacked startup times.
3. **Linux Mint** — Comfortable like slippers, but never quite the bleeding-edge sandbox I wanted.
4. **Zorin OS** — Slick out of the box, but too curated for low-level plumbing.
5. **Kubuntu & Lubuntu** — Useful desktop experiments, but the underlying Debian/Ubuntu upgrade friction remained.
6. **Vanilla OS** — Clever immutable root architecture, but fighting immutability when hacking system internals is an acquired taste.
7. **Pop!_OS** — Admirable tiling window manager work, but tied to an external release cadence.

*(And then there was the side-quest tier: **Kali**, **Parrot Security**, and **Tails**. Let’s be completely honest—those were never serious daily-driver contenders. They were strictly for my occasional script-kiddy experiments, Wi-Fi auditing, and amnesic live-USB tinkering where keeping persistent dotfiles is impossible by design.)*

Two years ago, I installed **EndeavourOS**. And the hopping stopped for good.

EndeavourOS succeeded where the others stumbled because it got out of the way: a clean, bloat-free Arch Linux foundation, rolling packages the minute upstream tags them, and the unfettered reach of `pacman` and the AUR. For two solid years, it ran comfortably with **KDE Plasma 6**. Reliable, snappy, and uncomplaining.

Yet for over a year, I’d had an itch: I kept watching Hyprland demos from afar. The fluid Wayland shaders, the dynamic workspaces that spin up when you need them and vanish when empty, the pure keyboard-driven focus. But you know how it goes when you have a daily driver that works—you hesitate to burn a weekend ripping out your desktop environment.

Then, just a few days ago, the catalyst hit.

I stumbled across an article dismissively claiming that "Omarchy" Linux was nothing more than an "overhyped set of config files." 

That was the lightbulb moment. I realised: *hang on, if all the fuss is literally just a sharp set of Hyprland dotfiles on top of Arch, why am I still sitting here in Plasma? Why wait for someone else to package it?* 

That evening, I finally made the leap. I shifted from Plasma 6 into Hyprland, started crafting my native Lua config, and watched my workstation transform into a featherweight rocket ship.

The operating system was dialed in. The window manager was finally right. 

The remaining bottleneck was me.

---

## 2. The Biological Relay

In 2026, we have screaming-fast local GPUs and sub-second frontier LLMs. Yet developers are still acting as biological copper wire between their tools.

You know the routine:
* You're listening to music.
* You hit an idea or need to run a command.
* You fumble for media keys to mute Spotify.
* You alt-tab to a browser or an AI window.
* You type a prompt.
* You copy the snippet.
* You alt-tab back.
* You paste it into Ghostty.
* You unmute Spotify.

Then you hit a daily rate limit twenty minutes into your flow state, and the entire train of thought evaporates while you wait for a reset timer.

That is **The Biological Relay**: human beings burning mental context to manually shuttle text and state between the microphone, the browser, and the terminal.

The fix was obvious: speech had to type directly into the active cursor, audio ducking had to happen automatically in the sound server, and the AI copilot had to live natively in the terminal without quota anxiety.

---

## 3. The Giants and the Missing Edge

Existing speech and agent tooling solved pieces of this puzzle, but left glaring papercuts:

* **Wispr Flow**: I use Wispr Flow daily on my MacBooks for work—it’s slick, responsive, and genuinely brilliant in macOS. Naturally, my first thought was to track down a Linux wrapper and bring that exact workflow across to `shpadoinkle-1`. But under Hyprland, it was clunky at best. Wayland virtual keyboard friction, focus-stealing wrapper windows, zero integration with PipeWire audio streams, and that unmistakable feeling of an app fighting the compositor rather than living inside it.
* **Talon Voice** (~3k stars): Astonishingly capable for full hands-free accessibility. But constructing complex Python grammar trees just to dictate a quick bash one-liner into a terminal is like hiring an architect to hang a picture hook.
* **Whisper.cpp** (~38k stars): An exquisite C++ port. But batch-transcribing recorded WAV files from the command line is a world away from interactive, low-latency push-to-talk typing across Wayland panes.
* **Browser AI interfaces**: Great until you hit quota ceilings, lose terminal working-directory context, or spend your afternoon copying and pasting diffs back and forth.

We needed three things working in unison:
1. Push-to-talk transcription fast enough to feel instantaneous.
2. Intelligent PipeWire stream ducking so voice capture is pristine without touching volume knobs.
3. An AI terminal pairing workflow with generous quota and rapid-fire reasoning.

Enter **Gemini in the `agy` CLI** — and **Spud**.

---

## 4. Building Spud: From Zero to Voice Clone in 2.5 Hours

I paired with Gemini 3.8 Flash using Google's `agy` CLI to build [Spud](https://github.com/nihilok/spud): a local-first voice orchestrator written in Rust.

And when I say Gemini in `agy` has been a revelation, I mean it:
* **Generous Quota:** My usage never seems to run out. No quota countdowns. No artificial throttle.
* **The Personality:** Direct, sharp, slightly wry, zero corporate fluff.
* **Gemini 3.8 Flash:** Blazingly quick. It digests complex multi-crate Rust errors, PipeWire wireplumber node graphs, and Wayland virtual seat protocols without breaking sweat.

Because `agy` operates directly inside the repository with native tool execution, we didn't just write code — we built, tested, and debugged live.

Here is the git log from that single afternoon session:

```text
13:46:04 | Initial commit: Spud architecture and roadmap
13:50:14 | feat(stt): implement warm faster-whisper daemon & systemd unit
13:52:03 | feat(cli): compile native Rust CLI with STT client
13:55:11 | fix(injection): Hyprland signature fallback & wtype virtual typing
14:14:19 | feat(agent): Agent Command Mode with Herdr & LM Studio dispatch
14:37:13 | feat(ptt): Push-to-Talk Hold-and-Release with tap-filtering
15:13:51 | fix(dictation): route dictation via Wayland virtual keyboard
15:43:07 | feat(audio): automatic PipeWire audio ducking during dictation
15:54:09 | feat(tts): Phase 3 zero-shot cloned voice synthesis daemon
15:58:30 | fix(audio): duck per-stream media players (keep voice at 100%)
16:02:42 | feat(tts): vocal mastering with soft-knee compression & +10dB
16:11:16 | perf(tts): pipelined streaming, x-vector fast mode & audio earcons
16:13:46 | feat(agent): inject live date/time into system prompt
19:14:04 | feat(dict): custom dictionary and phonetic jargon reinforcement
```

**Two hours and twenty-seven minutes.**

In that window, we went from an empty directory to:
1. **Push-to-Talk Terminal Dictation (`Super + D`)**: Captures audio with micro-tap filtering, ducks background media streams to 50% via PipeWire (`wpctl`), feeds a warm `faster-whisper` CUDA daemon (`/tmp/spud-stt.sock`), and types into the focused window using `wtype` (Wayland virtual keyboard) at sub-200ms latency.
2. **Jargon Reinforcement (`src/dict.rs`)**: Pre-conditions Whisper's vocabulary with terms like `shpadoinkle-1`, `Hyprland`, `Herdr`, `wtype`, `PipeWire`, and `kubectl`, coupled with deterministic phonetic replacement rules so technical jargon is never misheard.
3. **Agent Mode & Cloned Voice Egress (`Super + Shift + D`)**: Dispatches commands to local agent panes, queries local LLMs, and synthesizes verbal responses through a warm `Qwen3-TTS` daemon on CUDA using cached speaker embeddings and soft-knee audio compression.
4. **Self-Improving Desktop Skills**: Antigravity skills (like `add-shortcut`) allow the agent to inspect Hyprland configurations, validate keybindings, and trigger live `hyprctl` reloads without touching a config file by hand.

---

## 5. The Maths

| Metric | The Biological Relay | Spud + Gemini (`agy`) |
|---|---|---|
| **Dictation Latency** | 3–6s (cloud API / batch STT) | <200ms (`faster-whisper` on CUDA) |
| **Audio Ducking** | Manual keyboard faffing | Automatic PipeWire stream attenuation (50%) |
| **Cursor Typing** | Clipboard copy-pasting | Native Wayland `wtype` at focused cursor |
| **Tech Jargon Accuracy** | Fails on `kubectl`, `wtype` | Deterministic phonetic dictionary |
| **Wayland & Hyprland Fit** | Clunky wrappers, focus loss, XWayland hacks | Zero-overhead native Wayland daemon (`wtype`) |
| **Agent Egress** | Reading terminal blocks | Zero-shot cloned voice TTS audio debrief |
| **Pairing Quota** | Daily exhaustion anxiety | Endless practical quota, zero interruptions |
| **Initial Implementation** | 2–3 weeks of weekend hacking | 2 hours 27 minutes |

---

## The Receipt

The biological relay is retired.

Give your terminal a voice. Let your music duck itself. Let your desktop configure its own shortcuts.

```bash
# Clone and build Spud
git clone git@github.com:nihilok/spud.git ~/Code/spud
cd ~/Code/spud && cargo build --release
```

[Spud on GitHub](https://github.com/nihilok/spud)
