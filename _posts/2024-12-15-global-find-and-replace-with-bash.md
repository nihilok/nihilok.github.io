---
layout: post
title: "Global find and replace with bash"
date: 2024-12-15
---

I'm working on a server migration script (watch this space) where I need to do a global find and replace in a bunch of files on a VPS (Virtual Private Server). I'm currently reading a bbok called "Cybersecurity Ops with bash" by Paul Troncone, which has been a great resource for learning bash scripting, and I found a solution in the book that I can use to do the global find and replace:

```bash
find /path/to/files -type f -exec sed -i 's/old-text/new-text/g' {} +
```

This command will find all standard files (`-type f`) in the specified directory and replace all instances of "old-text" with "new-text". The `-i` flag tells `sed` to edit the files in place, so be careful when using this command. The `+` at the end of the command is used to group the files together, which can improve performance when dealing with a large number of files.

We can improve performance even further by using the `xargs` command:

```bash
find /etc/. -type f -print0 | xargs -0 sed -i "s/old-text/new-text/g"
```

This command will also find all standard files in the specified directory, print them with a null character separator, and then pass them to `xargs` which will run the `sed` command on each file. The `-0` flag tells `xargs` to use the null character as the separator, which is useful for dealing with files that have spaces or special characters in their names.

We can incorporate this command into a bash script to make it easier to use:

```bash
#!/bin/bash

# Check for the correct number of arguments
if [ $# -ne 3 ]; then
    echo "Usage: $0 <directory> <old-text> <new-text>"
    exit 1
fi

echo "Replacing $2 with $3 in files in ${1}..."
find $1 -type f -print0 | xargs -0 sed -i "s/$2/$3/g"
echo "Done."
```

Save this script as `global_replace.sh` and make it executable with `chmod +x global_replace.sh`. You can then use it like this:

```bash
./global_replace.sh /path/to/files "Some text" "Some other text"
```

This will replace all instances of "Some text" with "Some other text" in the files in the specified directory which contained the text "Some text" (any other files will be ignored). Happy scripting!
