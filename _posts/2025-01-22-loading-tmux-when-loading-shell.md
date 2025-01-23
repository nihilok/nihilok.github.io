---
layout: post
title: "Loading tmux when loading shell"
date: 2025-01-22
---

This is something I've had mixed success with in the past. I've had things that worked but not quite in the way I wanted them to, and other things that just didn't work! (Try sticking an `exec` before an error in `.zshrc`, and you've just nerfed your shell startup!)

There are a few things we need to consider, e.g. Do we want the same session as last time? What if there is no session? Can we create a new session but attach to an existing one if one by the same name exists? Do we want the same session when on SSH? Or when running a terminal emulator inside an IDE for example?

I've finally nailed it down to the following:

```zsh
#!/usr/bin/env zsh

if [[ $TERMINAL_EMULATOR != "JetBrains-JediTerm" ]] && [[ -z $TMUX ]]; then
        if [[ -n $SSH_CONNECTION ]]; then
            TMUX_SESSION_NAME="tmux_$(echo "$SSH_CONNECTION" | md5sum | cut -d ' ' -f 1 | cut -c 1-6)"
        else
            TMUX_SESSION_NAME="tmux"
        fi
        if tmux has-session -t "$TMUX_SESSION_NAME" 2>/dev/null; then
            exec tmux attach -t "$TMUX_SESSION_NAME"
        else
            exec tmux new-session -s "$TMUX_SESSION_NAME"
        fi
    fi
fi
```

This script will start a new tmux session if one doesn't exist, or attach to an existing one if it does. It will also create a new session if you're on SSH, and it will not run if you're using the JetBrains terminal emulator (as it doesn't play nicely with tmux).

I have this in a separate script, `~/.load_tmux` which I source from my `.zshrc`, right at the top of the file (so that it is the first thing that is executed):

```zsh
source ~/.load_tmux
# rest of .zshrc...
```
