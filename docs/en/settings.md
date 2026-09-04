---
layout: default
title: Settings and appearance
---

# Settings and appearance

Press `Z` or `Command+,` to open Settings. You can change startup locations, action confirmations, file-list appearance, themes, and keybindings.

![General settings with v0.6.0 options](../assets/screenshots/settings-general.png)

## General

General settings include the app language, Return key behavior, incremental search matching, and startup locations for the left and right panes. You can set the file-list font size from 8 to 24 pt.

Return key behavior applies only to unmodified `Return` in the main pane. By default it opens the selected directory, but it can also preview files while opening directories, or do nothing.

Incremental search can use prefix, contains, or exact matching.

Enable “Incremental search priority” to use unmodified letters, numbers, and symbols as incremental-search input first. Disable it if you want those keys to execute regular keybindings. It is disabled by default.

Enable “Treat ZIP files as directories” to browse a selected ZIP file inside the pane with `Enter`. When disabled, ZIP files are treated like regular files. It is enabled by default.

Enable **Show preview pane** to show an auxiliary preview that follows the selected item. Choose **Preview pane position** to place it on the left or right. A width changed by dragging or in preview mode is restored at the next launch.

## Operations and confirmations

Confirmations for copy, move, move to Trash, and quit can be toggled individually. You can also set the number of file-operation detail log entries. Use `0` to show all entries.

Operation behavior settings include moving the cursor after marking, entering newly created folders, and selecting the previous directory after moving to the parent directory.

**Allow file drag to other applications** is off by default. When enabled, you can drag files from a list to another application as copies.

## Import and export settings

Use **Import…** and **Export…** at the bottom of Settings to read and write JSON settings files. Imported settings are not applied until you press OK in the Settings window. Press Cancel or `Esc` to discard them.

You can also import keybindings only or custom themes only. Invalid files or unsupported values are rejected without changing existing settings.

## Built-in themes

Choose from Light, Dark, Dracula, Nord, Solarized Light, and Solarized Dark. Switch the file-list background, text colors, and accent colors to suit your environment.

| Light | Dark |
| --- | --- |
| ![Light theme](../assets/screenshots/theme-light.png) | ![Dark theme](../assets/screenshots/theme-dark.png) |
| Dracula | Nord |
| ![Dracula theme](../assets/screenshots/theme-dracula.png) | ![Nord theme](../assets/screenshots/theme-nord.png) |
| Solarized Light | Solarized Dark |
| ![Solarized Light theme](../assets/screenshots/theme-solarized-light.png) | ![Solarized Dark theme](../assets/screenshots/theme-solarized-dark.png) |

## Custom themes

You can also adjust display colors to create your own theme, including colors for the selected row, marked rows, and message area.

![Custom theme example](../assets/screenshots/theme-custom.png)

## File type settings

For each file extension, you can configure an application and a list color. Files with a configured application can be opened with that application using the default `Control+Return` shortcut.

**Other** applies to ordinary files that have no specific extension setting, including files with no extension. It does not apply to directories or special items. A specific extension setting takes precedence over **Other**.

## Zebra rows

Enable alternating row backgrounds to make long file lists easier to scan.

![Zebra rows with the Dark theme](../assets/screenshots/theme-dark-zebra.png)

Next: [Keybindings](keybindings.md)
