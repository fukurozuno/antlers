---
layout: default
title: ZIP and archive operations
---

# ZIP and archive operations

Antlers 0.6.0 can browse ZIP files in a pane, extract them, and create ZIP files. As with other file operations, marked items are used when any items are marked; otherwise the selected item is used.

## Browse ZIP contents

Select a ZIP file and press `X, O` to show its contents in the pane. When “Treat ZIP files as directories” is enabled in General, unmodified `Enter` does the same.

You can open directories inside the ZIP. Press `Backspace` to move to the parent level, and press it again at the ZIP root to return to the regular file list.

![Browsing ZIP contents](../assets/screenshots/archive-browsing.png)

Items inside a ZIP are virtual items. They cannot be used as targets for regular copy, move, rename, or Trash operations.

## Extract a ZIP

Select a ZIP file and press `X, E`. The destination is proposed as a new folder, named after the ZIP without its extension, in the current directory of the opposite pane. Review the confirmation dialog and choose **Extract**.

![ZIP extraction confirmation](../assets/screenshots/archive-extract-dialog.png)

Existing files and folders are not overwritten. If extraction fails, a partial output is not committed.

## Create a ZIP

Mark items and press `X, C` to compress them into a ZIP in the current directory of the opposite pane. Enter a ZIP file name and choose **Create**. The `.zip` extension is added when it is omitted.

![ZIP creation confirmation](../assets/screenshots/archive-create-dialog.png)

## Operation limits

- The pane browsing a ZIP cannot be used as a regular operation destination.
- Extraction and creation are disabled when the opposite pane is browsing a ZIP.
- Archives containing absolute paths or `..` path components are rejected.
- Symbolic links in ZIP files are not supported.
- Archives exceeding the safety limits for expanded size or entry count are rejected.

See [Safe operations](safety.md) for details.

[Back to file operations](file-operations.md)
