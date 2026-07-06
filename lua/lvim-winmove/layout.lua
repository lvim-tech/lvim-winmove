-- lvim-winmove.layout: window neighbour + wall resolution.
-- A directional move relocates the current window next to its neighbour in that direction; we
-- resolve the neighbour with the native `wincmd` motion (winnr("h"/"j"/"k"/"l")) rather than
-- reimplementing geometry — the same adjacency Vim uses for CTRL-W h/j/k/l. A window is a WALL
-- (never displaced into) when its buffer is excluded or it is size-fixed.
--
---@module "lvim-winmove.layout"

local api = vim.api
local fn = vim.fn

local M = {}

-- direction → the wincmd motion letter used to find the neighbour that way.
---@type table<string, string>
local MOTION = { left = "h", down = "j", up = "k", right = "l" }

--- Whether `win` is a wall: an excluded buftype/filetype, or a size-fixed window.
---@param win integer
---@param cfg LvimWinMoveConfig
---@return boolean
function M.is_wall(win, cfg)
    if not api.nvim_win_is_valid(win) then
        return true
    end
    if vim.wo[win].winfixwidth or vim.wo[win].winfixheight then
        return true
    end
    local buf = api.nvim_win_get_buf(win)
    local ex = cfg.exclude or {}
    for _, bt in ipairs(ex.buftype or {}) do
        if vim.bo[buf].buftype == bt then
            return true
        end
    end
    for _, ft in ipairs(ex.filetype or {}) do
        if vim.bo[buf].filetype == ft then
            return true
        end
    end
    return false
end

--- The window immediately in `dir` of `win` on the current tabpage, or nil when `win` is at
--- that edge (no neighbour). Uses Vim's own adjacency via winnr(<motion>).
---@param win integer
---@param dir "left"|"down"|"up"|"right"
---@return integer? neighbour
function M.neighbour(win, dir)
    local motion = MOTION[dir]
    if not motion then
        return nil
    end
    -- winnr(motion) is evaluated relative to the CURRENT window; run it in `win`'s context.
    local nb_nr = api.nvim_win_call(win, function()
        return fn.winnr(motion)
    end)
    local nb = fn.win_getid(nb_nr)
    if nb == 0 or nb == win then
        return nil -- at the edge: winnr(motion) returns the current window number
    end
    return nb
end

return M
