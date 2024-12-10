---
layout: post
title: "Detecting a Loop"
date: 2024-12-10
---

OpenAI's `o1-mini` (coding/reasoning) model had this to say about detecting a loop in a 2D grid:

To determine whether there's a possible looping path in a 2D grid of `MapPosition` objects—where the loop can be any closed path (not necessarily a perfect rectangle or square) and may include branches or paths outside the loop—you'll need to perform a more generalized cycle detection within the grid.

### **Problem Clarification**

- **Loop Definition:** A loop is a closed path where you can start at a cell and return to it by traversing adjacent cells (horizontally or vertically) without retracing your steps. For the loop to be valid:
  - **Each cell in the loop must have been visited at least twice** (`num_times_visited >= 2`), indicating that the path has entered and exited each cell in the loop.

- **Additional Paths/Bananas:** There can be branches or paths outside the loop that might have cells visited fewer times, but these should not affect the existence of the loop.

### **Approach Overview**

To solve this, we'll treat the grid as a graph where each `MapPosition` is a node connected to its adjacent nodes (up, down, left, right). We are interested in finding **any cycle** in this graph where:

- All nodes in the cycle have `num_times_visited >= 2`.

This way, the cycle represents a looped path that has been traversed at least twice, satisfying the condition for a looping path.

### **Cycle Detection Using Depth-First Search (DFS)**

We'll implement a **Depth-First Search (DFS)** algorithm tailored for cycle detection in undirected graphs. Here's how:

1. **Graph Representation:**
   - Consider each cell with `num_times_visited >= 2` as a node.
   - Connect nodes to their adjacent (up, down, left, right) neighbors that also have `num_times_visited >= 2`.

2. **DFS Traversal:**
   - Traverse the graph using DFS.
   - Keep track of visited nodes to avoid redundant processing.
   - During traversal, if we encounter an already visited node that's not the immediate parent, a cycle exists.

3. **Handling Grid Boundaries:**
   - Ensure that adjacency checks respect the grid's boundaries to avoid index errors.

### **Implementation**

Here's the Python implementation adhering to the above approach:

```python
from dataclasses import dataclass
from typing import List, Set, Tuple

@dataclass
class MapPosition:
    x: int
    y: int
    num_times_visited: int = 0

def has_looping_path(grid: List[List[MapPosition]]) -> bool:
    if not grid or not grid[0]:
        return False

    rows = len(grid)
    cols = len(grid[0])

    visited = [[False for _ in range(cols)] for _ in range(rows)]

    def is_valid(y: int, x: int) -> bool:
        return 0 <= y < rows and 0 <= x < cols and grid[y][x].num_times_visited >= 2

    def dfs(y: int, x: int, parent_y: int, parent_x: int) -> bool:
        visited[y][x] = True

        # Define the four possible directions: up, down, left, right
        directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]

        for dy, dx in directions:
            ny, nx = y + dy, x + dx

            if not is_valid(ny, nx):
                continue  # Skip invalid or unqualified cells

            if not visited[ny][nx]:
                if dfs(ny, nx, y, x):
                    return True
            elif ny != parent_y or nx != parent_x:
                # Found a neighbor that's visited and not the parent => cycle
                return True

        return False

    for y in range(rows):
        for x in range(cols):
            if grid[y][x].num_times_visited >= 2 and not visited[y][x]:
                if dfs(y, x, -1, -1):
                    return True

    return False
```

### **Explanation**

1. **Initial Checks:**
   - The function first checks if the grid is empty. If so, it returns `False` since no loops can exist.

2. **Visited Matrix:**
   - A 2D `visited` matrix keeps track of which cells have been processed during DFS to prevent redundant traversals.

3. **Helper Functions:**
   - `is_valid(y, x)`: Checks if the cell `(y, x)` is within grid boundaries and has been visited at least twice (`num_times_visited >= 2`).

4. **Depth-First Search (`dfs`):**
   - Marks the current cell as visited.
   - Iterates through all four possible adjacent directions (up, down, left, right).
   - For each valid neighbor:
     - If the neighbor hasn't been visited, recursively perform DFS on it.
     - If the neighbor has been visited and is **not** the parent from which we arrived, a cycle is detected, and the function returns `True`.

5. **Main Loop:**
   - Iterates through every cell in the grid.
   - For each cell that qualifies (i.e., `num_times_visited >= 2` and not yet visited), it initiates a DFS.
   - If any DFS traversal finds a cycle, the function immediately returns `True`.
   - If no cycles are found after exploring all qualifying cells, the function returns `False`.

### **Time and Space Complexity**

- **Time Complexity:** O(rows * cols), since each cell is visited at most once.

- **Space Complexity:** O(rows * cols) for the `visited` matrix and recursion stack in the worst case.

### **Example Usage**

Here's how you might use the `has_looping_path` function with a sample grid:

```python
# Example grid:
# A 3x3 grid where the outer perimeter forms a loop visited twice,
# and the inner cell is visited once.

grid = [
    [MapPosition(x=0, y=0, num_times_visited=2), MapPosition(x=1, y=0, num_times_visited=2), MapPosition(x=2, y=0, num_times_visited=2)],
    [MapPosition(x=0, y=1, num_times_visited=2), MapPosition(x=1, y=1, num_times_visited=1), MapPosition(x=2, y=1, num_times_visited=2)],
    [MapPosition(x=0, y=2, num_times_visited=2), MapPosition(x=1, y=2, num_times_visited=2), MapPosition(x=2, y=2, num_times_visited=2)]
]

print(has_looping_path(grid))  # Output: True
```

In this example, the outer perimeter of the grid forms a cycle (loop) where each perimeter cell has been visited at least twice (`num_times_visited >= 2`). The inner cell `(1,1)` is visited only once and does not affect the existence of the external loop. Hence, the function returns `True`.

### **Alternative: Detecting Rectangular/Square Loops**

If your specific application requires detecting only rectangular or square loops (as opposed to any arbitrary cycle), the initial approach proposed can be utilized. Here's a refined version focusing on rectangular/square loops with early termination for efficiency:

```python
def has_rectangular_loop(grid: List[List[MapPosition]]) -> bool:
    if not grid or not grid[0]:
        return False

    rows = len(grid)
    cols = len(grid[0])

    # Precompute visited cells
    visited_cells = set()
    for y in range(rows):
        for x in range(cols):
            if grid[y][x].num_times_visited >= 2:
                visited_cells.add((y, x))

    # Iterate through all possible rectangles
    for y1 in range(rows):
        for x1 in range(cols):
            if (y1, x1) not in visited_cells:
                continue  # Skip cells not visited enough

            for y2 in range(y1 + 1, rows):
                for x2 in range(x1 + 1, cols):
                    # Check if all perimeter cells of the rectangle are in visited_cells
                    is_loop = True

                    # Top and Bottom edges
                    for x in range(x1, x2 + 1):
                        if (y1, x) not in visited_cells or (y2, x) not in visited_cells:
                            is_loop = False
                            break

                    if not is_loop:
                        continue

                    # Left and Right edges
                    for y in range(y1 + 1, y2):
                        if (y, x1) not in visited_cells or (y, x2) not in visited_cells:
                            is_loop = False
                            break

                    if is_loop:
                        return True  # Found a valid rectangular loop

    return False
```

**Note:** This function specifically checks for rectangular or square loops where all perimeter cells have been visited at least twice. It avoids unnecessary checks by precomputing visited cells, which can offer some performance benefits over the initial assistant's approach.

### **Conclusion**

The generalized DFS-based cycle detection approach is more versatile and efficient for detecting any form of loop within the grid, regardless of its shape. However, if your application strictly requires detecting rectangular or square loops, the alternative method provided can be employed.

Choose the method that best aligns with your specific requirements:

- **General Loop Detection:** Use the DFS-based `has_looping_path` function.
- **Rectangular/Square Loop Detection:** Use the `has_rectangular_loop` function.

Both methods ensure that only loops where each involved cell has been visited at least twice are considered valid.
