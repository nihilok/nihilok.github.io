#!/bin/bash

# This script creates a new post in the _posts directory with the current date and the title provided as an argument.
# Usage: ./new_post.sh "Title of the post"

# Get the current date in the format YYYY-MM-DD
TODAY=$(date +%Y-%m-%d)

# Check if we're in the root directory of the Jekyll site by looking for the _posts directory, or if we're inside the _posts directory and create an absolute path accordingly
if [ -d "_posts" ]; then
  	POSTS_DIR="${PWD}_posts"
elif [ -d "../_posts" ]; then
	POSTS_DIR="${PWD}"
else
	echo "Error: Could not find the _posts directory. Make sure you're in the root directory of the Jekyll site."
	exit 1
fi

# Create a new file in the _posts directory with the current date and the title (from $1) in lowercase/kebab-case - if the title includes parentheses, then truncate the title at the first parenthesis.
FILENAME="${POSTS_DIR}/${TODAY}-$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | cut -d '(' -f 1).md"
touch "$FILENAME"

# Add the necessary front matter to the new file
echo -e "---\nlayout: post\ntitle: \"$1\"\ndate: $TODAY\n---" > "$FILENAME"

# Open the new file in the default text editor
$EDITOR "$FILENAME"
