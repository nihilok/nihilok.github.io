---
layout: post
title: "Runfiles That Replace the Commands You Always Forget"
---

You know the ones. The commands you've run a hundred times but still can't type from memory. The ones that live in your shell history, a Slack DM to yourself, or a sticky note called `commands.txt` on your desktop.

[run](https://runtool.dev) lets you turn them into named functions. Here are some real ones from my projects.

## 1. The database query you run twelve times a day

```bash
# @desc Query the project database
# @arg query SQL query to run
db(query) {
    psql "$DATABASE_URL" -c "$query"
}
```

```
$ run db "SELECT count(*) FROM users WHERE created_at > now() - interval '1 day'"
```

No more pasting connection strings. No more `ctrl+r psql`. Just `run db`.

## 2. The Docker cleanup you always have to Google

```bash
# @desc Nuke all stopped containers, dangling images, and unused volumes
nuke() {
    docker system prune -af --volumes
}
```

Is it `docker system prune`? `docker container prune`? Does it need `-f`? `--volumes`? You looked this up last week and you'll look it up again next week. Or you could just `run nuke`.

## 3. The SSH tunnel with too many flags

```bash
# @desc Open SSH tunnel to the staging database
# @arg port Local port to bind (default: 5433)
tunnel(port = "5433") {
    ssh -N -L $port:staging-db.internal:5432 bastion.example.com
}
```

```
$ run tunnel
$ run tunnel 5434  # different local port
```

## 4. "What's using that port?"

```bash
# @desc Find and optionally kill the process on a port
# @arg port Port number to check
port(port: int) {
    #!/usr/bin/env python
    import subprocess, sys
    result = subprocess.run(["lsof", "-ti", f":{port}"], capture_output=True, text=True)
    if not result.stdout.strip():
        print(f"Nothing on port {port}")
        sys.exit(0)
    pids = result.stdout.strip().split("\n")
    for pid in pids:
        proc = subprocess.run(["ps", "-p", pid, "-o", "comm="], capture_output=True, text=True)
        print(f"PID {pid}: {proc.stdout.strip()}")
}
```

Notice this one uses Python — because parsing `lsof` output in bash is the kind of thing that makes you question your career choices. In a Runfile, you pick the right language for the job.

## 5. The deploy you're always scared to get wrong

```bash
# @desc Deploy to an environment
# @arg env Target environment (staging|prod)
# @arg tag Docker image tag to deploy
deploy(env, tag) {
    echo "Deploying $tag to $env..."
    kubectl set image deployment/app app=registry.example.com/app:$tag -n $env
    kubectl rollout status deployment/app -n $env
}
```

```
$ run deploy staging v1.4.2
```

No more double-checking which cluster context you're in. No more accidentally deploying to prod because you fat-fingered the namespace.

## 6. The workflow that ties it all together

```bash
# @desc Run the full local CI check
ci() {
    run lint
    run fmt
    run test
    run build
}
```

Runfile functions can call other Runfile functions. `run ci` runs your linter, formatter, tests, and build — in order, stopping on failure. Four lines, and you've gone from "aliases for things I forget" to actual workflow automation.

## The pattern

If you're hitting `ctrl+r` for it, it should be a function. If it has flags you can't remember, it should be a function. If getting it wrong has consequences, it *definitely* should be a function.

A [Runfile](https://runtool.dev/docs) is just a file full of functions. If you can write bash (or Python, or Node), you can write a Runfile. No build system to learn. No config format to memorise. Your Runfile is just the commands you already run, with names.

```bash
brew install nihilok/tap/runtool
# or
cargo install run
```

The code is on [GitHub](https://github.com/nihilok/run).
