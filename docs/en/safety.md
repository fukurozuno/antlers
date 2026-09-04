---
layout: default
title: Safe operations
---

# Safe operations

Antlers prioritizes prevention of data loss over convenience.

- `D` moves items to Trash instead of permanently deleting them.
- You can enable confirmations before copy, move, moving to Trash, and quitting. Overwrite confirmation is always shown when renaming.
- Operations that may overwrite an existing item require explicit confirmation.
- Check results in the message area at the bottom of the window.
- ZIP extraction does not overwrite an existing destination and commits the result only after extraction into a temporary directory succeeds.
- ZIP archives with absolute paths, `..` path components, symbolic links, or more entries/expanded data than the safety limits allow are rejected.

Before working with important files, make sure a backup is available. In every confirmation dialog, review the items, count, and destination.

[Back to file operations](file-operations.md)

[ZIP and archive operations](archive-operations.md)
