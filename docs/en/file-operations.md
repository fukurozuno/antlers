---
layout: default
title: File operations
---

# File operations

When items are marked, actions apply to the marked items; otherwise they apply to the selected item. The destination is normally the current directory in the opposite pane.

| Key | Action |
| --- | --- |
| `C` | Copy to the opposite pane |
| `M` | Move to the opposite pane |
| `D` | Move to Trash |
| `R` | Rename the selected item |
| `Shift+R` | Copy with a new name in the same directory |
| `K` | Create a folder in the current directory |

## Confirm before copying

Before copying, you can review the item count, destination, and source paths. Select **Copy** only after checking the details, or choose **Cancel** to stop.

![Copy confirmation dialog (Japanese UI)](../assets/screenshots/copy-dialog.png)

Potential overwrites require explicit confirmation. Deleting moves items to Trash rather than permanently deleting them. See [Safe operations](safety.md).
