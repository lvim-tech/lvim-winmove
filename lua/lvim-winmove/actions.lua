-- lvim-winmove.actions: the window rearrange primitives.
--   move(dir) — slide the current window one slot, past its neighbour in `dir`. Uses
--               `win_splitmove` (the proper API — it relocates the window WITHOUT close+split,
--               so window options and the view are preserved), targeting the directional
--               neighbour. A wall neighbour or a true edge is a no-op.
--   far(dir)  — move the window to the corresponding screen edge, full height/width. This is
--               exactly Vim's native `wincmd H/J/K/L`.
--   swap(tgt) — exchange the current and target windows' BUFFER + view, so the two windows
--               swap content while each keeps its own position and local options.
--
-- A move or far-move runs with the WALLS held at their size and then EQUALISES the tab
-- (`config.equalize`) — see `with_walls_held`.
--
---@module "lvim-winmove.actions"

local api = vim.api
local fn = vim.fn
local layout = require("lvim-winmove.layout")

local M = {}

-- direction → win_splitmove flags (vertical = a left/right split; rightbelow = which side).
---@type table<string, { vertical: boolean, rightbelow: boolean }>
local SPLIT = {
    left = { vertical = true, rightbelow = false },
    right = { vertical = true, rightbelow = true },
    up = { vertical = false, rightbelow = false },
    down = { vertical = false, rightbelow = true },
}

-- direction → the native far-move wincmd.
---@type table<string, string>
local FAR = { left = "H", down = "J", up = "K", right = "L" }

--- The kind of frame each window sits in: "row" (side by side — its WIDTH is what it owns) or "col"
--- (stacked — its HEIGHT). nil for a lone window.
---@return table<integer, "row"|"col">
local function frame_kinds()
    local kinds = {}
    local function walk(node, parent)
        if node[1] == "leaf" then
            kinds[node[2]] = parent
        else
            for _, child in ipairs(node[2]) do
                walk(child, node[1])
            end
        end
    end
    walk(fn.winlayout(), nil)
    return kinds
end

--- The walls of the tab with their own 'winfixwidth' / 'winfixheight', to be restored afterwards.
---@param cfg table
---@return { win: integer, fw: boolean, fh: boolean }[]
local function walls_of_tab(cfg)
    local walls = {}
    for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
        if api.nvim_win_get_config(w).relative == "" and layout.is_wall(w, cfg) then
            walls[#walls + 1] = { win = w, fw = vim.wo[w].winfixwidth, fh = vim.wo[w].winfixheight }
        end
    end
    return walls
end

--- Pin each wall in the ONE dimension it owns where it sits now: side by side with others it keeps its
--- width, stacked it keeps its height (its own winfix options stay as they were). Pinning both would lock
--- a sidebar at whatever height a far-move leaves it, and the whole row with it.
---@param walls { win: integer, fw: boolean, fh: boolean }[]
local function pin(walls)
    local kinds = frame_kinds()
    for _, x in ipairs(walls) do
        if api.nvim_win_is_valid(x.win) then
            vim.wo[x.win].winfixwidth = x.fw or kinds[x.win] == "row"
            vim.wo[x.win].winfixheight = x.fh or kinds[x.win] == "col"
        end
    end
end

---@param walls { win: integer, fw: boolean, fh: boolean }[]
local function unpin(walls)
    for _, x in ipairs(walls) do
        if api.nvim_win_is_valid(x.win) then
            vim.wo[x.win].winfixwidth = x.fw
            vim.wo[x.win].winfixheight = x.fh
        end
    end
end

--- Run a rearrange with the walls held at their size, then equalise the tab (`config.equalize`).
---
--- The walls are pinned BEFORE the move, not only for `wincmd =`: a window leaving a row hands its width
--- to the neighbour, and a file panel recognised by its buffer (no winfix option of its own) was that
--- neighbour — a far-move took a 30-column panel to 80 by itself. Then, with 'equalalways' off, Vim leaves
--- the moved window its old size in its new place: sent to the bottom, it kept the full height and left the
--- rest of the screen ONE row. `wincmd =` settles both, the way 'equalalways' would.
---@param cfg table
---@param rearrange fun()
---@return boolean ok
local function with_walls_held(cfg, rearrange)
    local walls = walls_of_tab(cfg)
    pin(walls)
    local ok = pcall(rearrange)
    if ok and cfg.equalize ~= false then
        pin(walls) -- the move may have changed which kind of frame a wall sits in
        pcall(vim.cmd, "wincmd =")
    end
    unpin(walls)
    return ok
end

--- Slide the current window one slot in `dir`, past its neighbour. No-op (returns false) at an
--- edge or against a wall.
---@param dir "left"|"down"|"up"|"right"
---@return boolean moved
function M.move(dir)
    local cfg = require("lvim-winmove.config")
    local flags = SPLIT[dir]
    if not flags then
        return false
    end
    local cur = api.nvim_get_current_win()
    -- The window being moved is itself a wall (an excluded buffer or a size-fixed panel): relocating
    -- a fixed-width sidebar with win_splitmove would tear it out of place, so refuse at the source.
    if layout.is_wall(cur, cfg) then
        return false
    end
    local nb = layout.neighbour(cur, dir)
    if not nb or layout.is_wall(nb, cfg) then
        return false
    end
    return with_walls_held(cfg, function()
        fn.win_splitmove(cur, nb, { vertical = flags.vertical, rightbelow = flags.rightbelow })
    end)
end

--- Far-move the current window to the `dir` edge, full height/width (native wincmd H/J/K/L).
---@param dir "left"|"down"|"up"|"right"
---@return boolean moved
function M.far(dir)
    local key = FAR[dir]
    if not key then
        return false
    end
    local cfg = require("lvim-winmove.config")
    if layout.is_wall(api.nvim_get_current_win(), cfg) then
        return false -- same reason as move(): don't fling an excluded/size-fixed panel to a screen edge
    end
    return with_walls_held(cfg, function()
        vim.cmd("wincmd " .. key)
    end)
end

--- Swap the current window's content with `target`'s: exchange their buffers and views. Each
--- window keeps its position and local options. No-op for an invalid/self target.
---@param target integer
---@return boolean swapped
function M.swap(target)
    local cur = api.nvim_get_current_win()
    if not target or target == cur or not api.nvim_win_is_valid(target) then
        return false
    end
    local cbuf, tbuf = api.nvim_win_get_buf(cur), api.nvim_win_get_buf(target)
    local cview = api.nvim_win_call(cur, fn.winsaveview)
    local tview = api.nvim_win_call(target, fn.winsaveview)
    api.nvim_win_set_buf(cur, tbuf)
    api.nvim_win_set_buf(target, cbuf)
    api.nvim_win_call(cur, function()
        fn.winrestview(tview)
    end)
    api.nvim_win_call(target, function()
        fn.winrestview(cview)
    end)
    return true
end

return M
