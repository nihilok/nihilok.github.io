# Nihilok Writing Style Guide

This guide codifies the voice, structure, cadence, and philosophy behind the essays and technical posts on `nihilok.github.io`. Use it whenever drafting new articles, cross-posts, social threads, or READMEs to keep the writing authentic and unmistakably distinct.

---

## 1. The Core Persona

**The Archetype:** *The Pragmatic Senior in the Trenches.*

- **Who you are:** The experienced engineer in the team who people naturally consult when their build breaks or a script behaves weirdly—not because you posture as a guru, but because you've spent years breaking things, fixing things, and reading the source code.
- **Attitude:** Candid, generous with knowledge, zero ego, slightly wry. You treat the reader as an intelligent peer sitting next to you at the terminal.
- **British English:** Always use British/Commonwealth spelling and phrasing:
  - *learnt* (not learned)
  - *behaviour* (not behavior)
  - *realised*, *memorised*, *organised* (not -ized)
  - *apologise* (not apologize)
  - *maths* (not math)
  - *put the kettle on*, *kung-fu*, *papercuts*

---

## 2. The 5-Beat Structural Blueprint

Every high-performing post follows this exact 5-beat narrative arc:

```
[1. In-Media-Res Cold Open]
            │
            ▼
[2. Name the Pain (Coin a Term)]
            │
            ▼
[3. Fair & Respectful Teardown of Alternatives]
            │
            ▼
[4. The Empirical Contrast ("The Maths")]
            │
            ▼
[5. Staccato Punchline & The Receipt]
```

### Beat 1: The In-Media-Res Cold Open
**Rule:** No throat-clearing. No generic introductory sentences like *"In this article, I will discuss..."* or *"Artificial intelligence has changed the way developers write software."*
Start directly inside the room, in the terminal, or in the broken build:
- *"Every Claude Code session starts the same way. You say 'run the tests.' The agent says 'I'll look for how to run tests in this project.'"*
- *"If you've spent any real time pairing with Claude Code, you've seen the dance."*
- *"Yes, I know. Another task runner. In 2026. Let me explain why."*
- *"We've all been there: you spin up a new server, and it's about as secure as a chocolate padlock..."*

### Beat 2: Name the Pain (Sticky Nomenclature)
Identify the unnamed friction that developers silently tolerate every day, and give it an unforgettable name:
- **"The Discovery Tax"**
- **"The Silent Ping"**
- **"The Godfather Session"**
- **"A chocolate padlock"**
- **"A better `.env` for commands"**
- **"Deterministic toolbox for a probabilistic mind"**

### Beat 3: Fair & Respectful Teardown of Alternatives
Never engage in cheap dunking on other tools. Respect the giants, quote their GitHub stars, acknowledge where they excel, and surgically isolate the exact edge where they fall short:
> *"**Just** (~22k stars) is the closest thing to what I wanted: a clean justfile with Make-inspired syntax, recipe parameters, shell completions. But parameters have no type annotations — they're positional strings and that's it. Handy for humans, but AI agents can't reliably introspect them."*

### Beat 4: The Empirical Contrast ("The Maths")
Back up the intuition with undeniable evidence. Use side-by-side terminal transcripts or clean markdown tables that compare token usage, round trips, or failure rates:

```text
Before (no MCP):
  [tool] cat README.md                           → 800 tokens
  [tool] ls scripts/                             → 50 tokens
  [tool] make test                               → fails (wrong target)
  Total: 6 tool calls, ~2,500 tokens of context consumed

After (RunTool MCP):
  [tool] mcp:runtool test                        → success
  Total: 1 tool call, ~100 tokens consumed
```

### Beat 5: Staccato Punchline & The Receipt
Finish with a short, memorable summary sentence, followed immediately by a 1-line installation or GitHub link:
> *"The discovery tax is zero."*
> *"Give your agent a name. Let it ping you like a real colleague. Your context window — and your kettle — will thank you."*
> 
> ```bash
> brew install nihilok/tap/runtool
> ```

---

## 3. Sentence Cadence & Rhythms

### Rapid Staccato Triplets
Use rapid-fire, fragmented sentences to simulate momentum, annoyance, or speed:
- *"Then it reads your README. Then your Makefile. Then your `package.json`. Then it tries `make test`. Wrong. `npm test`. Wrong project."*
- *"Ugly. Fragile. And it still broke in random edge cases."*
- *"No reading. No guessing. No retries."*

### Conversational Self-Awareness
Anticipate the reader's immediate reaction and call it out before they can:
- *"If you understand what `$(word 2,$(subst -, ,$@))` does without looking it up, congratulations — you're in the 1% of developers who've memorised Make's arcane variable substitution syntax."*
- *"I'm not a Make expert. But somehow I became the person people ask when they need to add a task to our Makefile."*

### Grounded Metaphors
Anchor high-level technical concepts to mundane physical realities:
- *Bouncers at an SSH config*
- *Chocolate padlocks*
- *Putting the kettle on while waiting for 300 tests*
- *Humans acting as biological copy-paste relays between terminal windows*

---

## 4. Vocabulary & Phrasing (The Lexicon)

### Words & Phrases to Embrace
- **Friction descriptors:** *arcane, papercuts, fragile, brittle, fumbling, faffing, flailing in the dark, boilerplate.*
- **System descriptors:** *deterministic, local-first, zero telemetry, behind NAT, atomic claims, plumbing.*
- **Transitions:** *"Yes, I know."*, *"Here's the problem:"*, *"The fix was obvious:"*, *"Enter my..."*, *"What if the agent already knew?"*
- **Phrasing:** *"in a nutshell"*, *"out of the box"*, *"zero guessing"*, *"the maths"*.

### Words to Ban (The AI / Corporate Slop List)
Never use corporate marketing fluff or generated AI cliches:
- ❌ *"delve"* / *"delving into"*
- ❌ *"game-changer"* (unless immediately qualified with technical specificity)
- ❌ *"seamlessly empowers developers"*
- ❌ *"in today's fast-paced digital landscape"*
- ❌ *"harness the power of"*
- ❌ *"revolutionizing the software development lifecycle"*
- ❌ *"testament to"* / *"beacon of"*

---

## 5. Technical Integrity & Code Conventions

1. **Real Code, Not Stubs:**
   Always provide real, working configurations, bash one-liners, or SQL tables. Avoid pseudo-code with `// do magic here`.
2. **Comment on Intent, Not Syntax:**
   Code comments should explain the operational rationale:
   ```bash
   # @desc Deploy to specified environment
   # @arg env Target environment (staging|prod)
   deploy(env) ./scripts/deploy.sh $env
   ```
3. **Show the Tool in Context:**
   Don't just paste code—show how a human or an agent interacts with it in the real shell.

---

## 6. Pre-Publish Sanity Checklist

Before publishing any draft or post, verify:

- [ ] Does the first paragraph throw the reader immediately into an active, relatable scene?
- [ ] Is there any throat-clearing in the intro that can be deleted?
- [ ] Are all spellings in British English (*learnt, behaviour, realised, maths*)?
- [ ] Did you coin or reinforce a sticky, memorable term?
- [ ] Are competitors treated fairly with star counts and genuine respect?
- [ ] Is there an empirical contrast (before/after snippet, table, or numbers)?
- [ ] Does the ending land with a crisp, staccato punchline and a clear receipt/link?
