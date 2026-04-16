# saywhatnow.nvim

A Neovim plugin that isolates the Git history of specific functions or code blocks, with an interactive side-by-side diff interface to scrub backward and forward through time.

## Overview

Unlike standard Git log tools that show the history of an entire file, `saywhatnow.nvim` uses Treesitter (or visual selections) to target specific lines of code. It queries Git for commits that modified only those lines, splits the window, and uses Neovim’s native diff engine to display the historical state of the code next to its current state.

## Core Features

- **Treesitter Context**: Automatically detects function/method boundaries around the cursor in Normal mode.
- **Visual Selection**: Supports arbitrary line ranges via Visual mode.
- **Time Scrubbing**: Step backward and forward through isolated commit history.
- **Native Diff Engine**: Uses Neovim’s `diffthis` for exact line highlighting and folding.
- **Dynamic Winbar**: Shows active commit hash, truncated commit message, and relative timestamp.
- **Floating Help**: On-demand keybind reference menu.

## Requirements

- Neovim `0.10.0+`
- `git` available in your system path
- `nvim-treesitter` configured with parsers for target languages

## Installation

```lua
return {
    dir = "/path/to/saywhatnow.nvim",
    config = function()
        require("saywhatnow").setup()

        vim.keymap.set("n", "<leader>gd", require("saywhatnow").start_normal, { desc = "SayWhatNow (Function)" })
        vim.keymap.set("v", "<leader>gd", require("saywhatnow").start_visual, { desc = "SayWhatNow (Selection)" })
    end
}
```

## Keybindings

### Global Activation

- `<leader>gd` (Normal): Launch diff for the function around the cursor.
- `<leader>gd` (Visual): Launch diff for highlighted lines.

### Inside the Diff Interface

- `H`: Load previous (older) commit that modified selected lines.
- `L`: Load next (newer) commit that modified selected lines.
- `?`: Open floating help menu.
- `q`: Close diff interface and restore original window layout.
- `<Esc>`: Close floating help menu (if open).

## Architecture

The plugin is structured into three modules:

- `treesitter.lua`: Finds `start_line` and `end_line` for functions/methods.
- `git.lua`: Runs async `git log -L` calls to collect commit metadata.
- `ui.lua`: Handles window splits, scratch buffers, winbar updates, diff sync, and buffer-local keymaps.
