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
    local nb = layout.neighbour(cur, dir)
    if not nb or layout.is_wall(nb, cfg) then
        return false
    end
    local ok = pcall(fn.win_splitmove, cur, nb, { vertical = flags.vertical, rightbelow = flags.rightbelow })
    return ok
end

--- Far-move the current window to the `dir` edge, full height/width (native wincmd H/J/K/L).
---@param dir "left"|"down"|"up"|"right"
---@return boolean moved
function M.far(dir)
    local key = FAR[dir]
    if not key then
        return false
    end
    return pcall(vim.cmd, "wincmd " .. key)
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
