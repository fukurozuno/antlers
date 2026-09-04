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
| `P, 1` | Copy file names to the clipboard |
| `P, 2` | Copy parent directory paths to the clipboard |
| `P, 3` | Copy full paths to the clipboard |
| `/` | Show the operation menu |

## Confirm before copying

Before copying, you can review the item count, destination, and source paths. Select **Copy** only after checking the details, or choose **Cancel** to stop.

![Copy confirmation dialog (Japanese UI)](../assets/screenshots/copy-dialog.png)

Potential overwrites require explicit confirmation. Deleting moves items to Trash rather than permanently deleting them. See [Safe operations](safety.md).

## Clipboard and context menu

Use `P, 1`, `P, 2`, and `P, 3` to copy file names, parent directory paths, or full paths as multi-line text. Targets follow the same rule as file operations: marked items when present, otherwise the selected item.

Press `/` to show the operation menu. Use the arrow keys and `Return` to choose an item, and `Esc` to close it. The menu can open an item, open it with a selected application, copy its path, copy/move/trash a selected or marked item, rename, copy with a new name, perform ZIP operations, and create a folder. In Confined Mode, some entries such as revealing an item in Finder or opening it in another application are disabled.

![Operation menu](../assets/screenshots/operation-menu.png)

## Drag files to other applications

Enable **Allow file drag to other applications** in General settings to drag files from a file list into another application. The drag provides copied file URLs and never moves items within Antlers.

Starting a drag from a marked item includes all marked items. Starting from an unmarked item includes only that item.

See [ZIP and archive operations](archive-operations.md) for browsing, extracting, and creating ZIP files.
