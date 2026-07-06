-- lvim-winmove: the live configuration table.
-- Holds the defaults; setup() merges user overrides into it IN PLACE (via
-- lvim-utils.utils.merge), so every require("lvim-winmove.config") reader sees the effective
-- values.
--
---@module "lvim-winmove.config"

---@class LvimWinMoveExclude
---@field buftype  string[]  Windows whose buffer has one of these 'buftype' values are treated as walls
---@field filetype string[]  Windows with one of these 'filetype' values are treated as walls (lvim panels)

---@class LvimWinMoveKeys
---@field left  string  Move one slot left (move mode)
---@field down  string  Move one slot down
---@field up    string  Move one slot up
---@field right string  Move one slot right
---@field far_left  string  Far-move to the left edge (full height)
---@field far_down  string  Far-move to the bottom edge (full width)
---@field far_up    string  Far-move to the top edge (full width)
---@field far_right string  Far-move to the right edge (full height)
---@field swap  string  Start a swap (pick a target via lvim-winpick)
---@field quit  string[]  Keys that leave move mode

---@class LvimWinMoveConfig
---@field keys      LvimWinMoveKeys      Move-mode keys
---@field exclude   LvimWinMoveExclude   Windows never displaced into (walls)
---@field hud_title boolean              Announce move mode in the statusline via the lvim-hud overlay

---@type LvimWinMoveConfig
return {
    -- Move-mode keys. h/j/k/l slide the window one slot; the upper-case variants far-move it to
    -- the corresponding screen edge; `s` starts a swap; the quit keys leave the mode.
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
    -- Windows treated as WALLS: a move never displaces into them, and swap skips them. Seeded
    -- with the lvim side panels + common trees (same spirit as lvim-winpick's filters). Windows
    -- with 'winfixwidth'/'winfixheight' are also treated as walls automatically.
    exclude = {
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
    -- Show a "WIN MOVE" title in the statusline (via lvim-hud.overlay) while the mode is active.
    hud_title = true,
}
