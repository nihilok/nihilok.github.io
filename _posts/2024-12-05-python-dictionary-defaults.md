---
title: "Python Dictionary Defaults"
date: 2024-12-05
---

Python dictionaries are incredibly versatile and widely used, but there are some handy tricks that can make using them much more streamlined and efficient. In this post, we'll explore `dict.setdefault` and `collections.defaultdict`.

## What is `dict.setdefault`?

The `dict.setdefault` method is a useful addition when working with dictionaries, particularly when dealing with missing keys. It checks if a key exists, and if it doesn't, it sets it with a default value. Here’s the syntax:

```python
dict.setdefault(key, default=None)
```

### Why Use `dict.setdefault`?

1. **Less Boilerplate Code**

   Instead of writing multiple lines to check for a key and add it if it’s missing, you can simplify it like this:

   **Without `setdefault`:**

   ```python
   if key not in my_dict:
       my_dict[key] = []
   my_dict[key].append(value)
   ```

   **With `setdefault`:**

   ```python
   my_dict.setdefault(key, []).append(value)
   ```

   Much tidier, wouldn’t you agree?

2. **Easier Data Aggregation**

   `setdefault` is excellent for grouping items or counting occurrences:

   ```python
   items = [('fruit', 'apple'), ('vegetable', 'carrot'), ('fruit', 'banana')]

   categorized = {}
   for category, item in items:
       categorized.setdefault(category, []).append(item)

   print(categorised)  # Output: {'fruit': ['apple', 'banana'], 'vegetable': ['carrot']}
   ```

## Meet `collections.defaultdict`

`defaultdict` takes things a step further. It automatically sets default values for missing keys using a factory function.

**Usage:**

```python
from collections import defaultdict

default_dict = defaultdict(default_factory)
```

### Why Use `defaultdict`?

1. **Automatic Default Initialisation**

   No need to check for keys manually:

   ```python
   from collections import defaultdict

   words = ['apple', 'banana', 'apple', 'orange', 'banana', 'apple']

   word_count = defaultdict(int)
   for word in words:
       word_count[word] += 1

   print(word_count)  # Output: defaultdict(<class 'int'>, {'apple': 3, 'banana': 2, 'orange': 1})
   ```

2. **Cleaner Code**

   It enhances readability by reducing repetitive patterns:

   ```python
   from collections import defaultdict

   items = [('fruit', 'apple'), ('vegetable', 'carrot'), ('fruit', 'banana')]

   categorized = defaultdict(list)
   for category, item in items:
       categorized[category].append(item)

   print(categorised)  # Output: defaultdict(<class 'list'>, {'fruit': ['apple', 'banana'], 'vegetable': ['carrot']})
   ```

3. **Supports Nested Structures**

   `defaultdict` makes creating nested dictionaries a breeze:

   ```python
   from collections import defaultdict

   nested_dict = defaultdict(lambda: defaultdict(int))
   nested_dict['group1']['item1'] += 1
   nested_dict['group1']['item2'] += 2

   print(nested_dict)
   ```

4. **Better Performance**

   It’s often faster, especially with numerous insertions or lookups.

## When to Use Which?

- **Use `dict.setdefault`** when you have a standard dict and only occasionally need default handling.

- **Use `defaultdict`** for more frequent missing key scenarios, especially when reading and writing to complex data structures.

## Conclusion

`dict.setdefault` and `defaultdict` are powerful tools that make working with dictionaries in Python less cumbersome. `setdefault` simplifies the handling of missing keys, while `defaultdict` takes care of default value management, resulting in clearer, more concise code.

I often notice people getting caught out with standard dictionary methods when they could be using these tools, and just today, `defaultdict` came in really handy when attempting to solve [an Advent of Code puzzle (Day 5, 2024)]({% post_url 2024-12-06-out-of-sorts %}) which was what prompted me to write this post! 🎅

Embrace the full potential of Python dictionaries with `setdefault` and `defaultdict`, and you'll be using the word "Pythonic" to describe your code in no time! 🐍🔑
