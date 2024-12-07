---
layout: post
title: "Out of Sorts: Advent of Code 2024 Day 5"
date: 2024-12-06
---

TL;DR: I failed miserably and resorted to cheating!

Today's puzzle focused on sorting. Part 1 was fairly straightforward and involved identifying correctly ordered lists of page numbers according to a set of rules around pages which must come before others. Part 2 was a bit more challenging and involved sorting a the incorrectly sorted lists of page numbers; I got very close, but in the end resorted to looking for hints in the [Advent of Code subreddit](https://www.reddit.com/r/adventofcode/) to get me over the line. Let's just say sorting algorithms are not my strong suit!

The puzzle input was in the following format:

```
47|53
97|13
97|61
97|47
75|29
61|13
75|53
29|13
97|29
53|29
61|53
97|53
61|29
47|13
75|47
97|75
47|61
75|61
47|29
75|13
53|13

75,47,61,53,29
97,61,53,29,13
75,29,13
75,97,47,61,53
61,13,29
97,13,75,29,47
```

The first part of the input is the sorting rules and the second part is the lists of page numbers.

Off the bat, I guessed I should try parse the input into a format that would be easier to work with, so I decided to create a dictionary where the keys are the page numbers and the values are the page numbers that must come before. I also parsed the pages to be checked into a list of lists.

```python
from collections import defaultdict

def parse_input(puzzle_input):
    ordering, lines = puzzle_input.split("\n\n")
    ordering = ordering.splitlines()
    ordering = [tuple(row.split("|")) for row in ordering]
    pages_before = defaultdict(
        list
    )  # dict of pages where the value is a list of pages that must come before the key
    for before, after in ordering:
        pages_before[after].append(before)
    lines = lines.splitlines()
    lines = [line.split(",") for line in lines]
    return pages_before, lines
```

I was pretty proud of the use of `defaultdict`, which immediately sprang to mind when I saw that the values would be lists. See [this post]({% post_url 2024-12-05-python-dictionary-defaults %}) which I composed as a result of how pleased with myself I was! I'll skip over part 1 as it was pretty trivial and jump straight into part 2. I was able to get this far pretty quickly:


```python
def part_2(puzzle_input):
    ordering, lines = parse_input(puzzle_input)

    incorrect_lines = []

    for line in lines:
        for i, page in enumerate(line):
            must_be_before = set(ordering[page])
            pages_after = set(line[i + 1 :])
            if must_be_before & pages_after:
                incorrect_lines.append(line)
                break

    sorted_lines = []

    for line in incorrect_lines:

        def sort_key(x):
           """SORT >>> ??? >>> PROFIT"""   # WTF should I do here??? 😵

        sorted_line = sorted(line, key=sort_key)
        sorted_lines.append(sorted_line)

    total = 0
    for line in sorted_lines:
        middle_item = line[len(line) // 2]
        total += int(middle_item)
    return total
```

I had several stabs at the `sort_key` function, but I just couldn't get it right. Eventually, I loaded up the subreddit with my tail between my legs and found [this insanely clever and consise solution](https://www.reddit.com/r/adventofcode/comments/1h71eyz/comment/m0i09b0/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button) which tackles both part 1 and part 2 in just a few lines of code:

```python
rules, pages = open('in.txt').read().split('\n\n')

a = [0, 0]
for p in pages.split():
    p = p.split(',')
    s = sorted(p, key=lambda x: -sum(x+'|'+y in rules for y in p))
    a[p!=s] += int(s[len(s)//2])

print(*a)
```

Notice there is no "clever" use of `defaultdict` here... in fact there's barely any code at all! After several rereads I was eventually able to fully understand the solution and adapt it to my own code without changing anything I'd already done, which I'm counting as a win! Where the above solution generates the sort key using the input in it's original format, I had already parsed the input into a dict, so I just needed to adapt the lambda function to use my dictionary of pages that must come before the key:

```python
def sort_key(x):
    return -sum(x in ordering[page] for page in line)
```

I learned several things from the ridiculous 7-line solution above; the most significant for this problem is the fact that bools are a subclass of ints in Python, so you can use them in arithmetic operations. Therefore, you can use the `sum` function to count the number of times a condition is met in a list comprehension/generator. They also make use of the same feature for indexing the `a` list where `p!=s` evaluating to `False` is Part 1 (correctly sorted lists) and `True` is Part 2 (incorrectly sorted lists).

With the weight of sorting off my mind I was also able to see that the 3 separate loops in my quick-and-dirty attempt were completely unnecessary and I could combine them into a single loop, meaning my final solution for part 2 was as follows:

```python
def part_2(puzzle_input):
    ordering, lines = parse_input(puzzle_input)
    total = 0
    for line in lines:
        for i, page in enumerate(line):

            def sort_key(x):
                return -sum(x in ordering[page] for page in line)

            must_be_before = set(ordering[page])
            pages_after = set(line[i + 1 :])

            if must_be_before & pages_after:
                sorted_line = sorted(line, key=sort_key)
                middle_item = line[len(line) // 2]
                total += int(middle_item)
                break

    return total
```

Check out my full solution for both parts [here](https://github.com/nihilok/advent-of-code-2024/blob/main/puzzles/day_5.py)

I definitely could not have come up with anything close to the final solution on my own, but I'm glad I was able to understand the extremely big-brain example I found, and adapt it to my own code. And I'm also not too disappointed with how far I was able to get by myself. It's all a learning exercise after all. Bring on Day 6! 🎄🎅🎁
