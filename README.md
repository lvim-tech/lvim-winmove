# lvim-winmove

Rearrange windows in the **lvim-tech** set — an interactive **move mode** (`h/j/k/l` carry the
current window through the layout, upper-case far-moves it to an edge, `s` swaps with a picked
window), plus one-shot directional / far / swap commands for direct keymaps.

Moves use the proper window APIs (`win_splitmove`, native `wincmd H/J/K/L`, and a buffer + view
swap) — never close-and-resplit, so window options and views survive. The move sub-mode is a modal
`getcharstr` loop (no timers); the moving window carries a subtle focus tint and the statusline
shows a **WIN MOVE** title while active.

[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://github.com/lvim-tech/lvim-winmove/blob/main/LICENSE)

## Requirements

Requires **Neovim >= 0.10** and [lvim-utils](https://github.com/lvim-tech/lvim-utils) (the focus
tint). Optional: [lvim-winpick](https://github.com/lvim-tech/lvim-winpick) (swap picks a target
window; without it, swap falls back to the first other non-wall window) and
[lvim-hud](https://github.com/lvim-tech/lvim-hud) (the WIN MOVE statusline title).

## Installation

### lvim-installer (recommended)

```vim
:LvimInstaller plugins
```

lvim-installer installs plugins through Neovim's built-in `vim.pack`, so no external plugin manager
is needed.

### Native (vim.pack)

```lua
vim.pack.add({
    { src = "https://github.com/lvim-tech/lvim-utils" },
    { src = "https://github.com/lvim-tech/lvim-winpick" }, -- optional (swap targeting)
    { src = "https://github.com/lvim-tech/lvim-winmove" },
})
require("lvim-winmove").setup({})
```

## Usage

```vim
:LvimWinMove                                 " enter move mode
:LvimWinMove left | right | up | down        " one-shot slide
:LvimWinMove far_left | far_right | far_up | far_down
:LvimWinMove swap                            " pick a window and swap content with it
```

```lua
require("lvim-winmove").move("left") -- one-shot slide
require("lvim-winmove").far("up") -- far-move to an edge
require("lvim-winmove").swap() -- pick a target and swap
require("lvim-winmove").enter() -- open move mode
```

In **move mode**: `h/j/k/l` slide the current window one slot, `H/J/K/L` far-move it to that edge,
`s` starts a swap, and `q` / `<Esc>` / `<CR>` leave. Windows that are side panels or size-fixed act
as **walls** — a move never displaces into them.

## Default configuration

```lua
require("lvim-winmove").setup({
    keys = {
        left = "h",
        down = "j",
        up = "k",
        right = "l",
        far_left = "H",
        far_down = "J",
        far_up = "K",
        far_right = "L",
        swap = "s",
        quit = { "q", "<Esc>", "<CR>" },
    },
    exclude = { -- walls: never displaced into (winfixwidth/height windows are walls too)
        buftype = { "nofile", "prompt", "quickfix", "terminal" },
        filetype = {
            "lvim-ui-frame",
            "lvim-utils-ui",
            "lvim-lsp-outline",
            "lvim-dashboard",
            "neo-tree",
            "Fyler",
            "qf",
            "help",
        },
    },
    hud_title = true, -- show a WIN MOVE title in the statusline (via lvim-hud) while active
})
```

## Highlights

`LvimWinMoveFocus` — the moving window's subtle whole-window tint (yellow), self-themed from
lvim-utils and overwritable by a colorscheme or your own `setup`.

## Health

```vim
:checkhealth lvim-winmove
```

Reports `win_splitmove` availability, the lvim-utils base, and the optional lvim-winpick / lvim-hud
integrations.
