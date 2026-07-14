-- lvim-winmove: rearrange windows — an interactive move sub-mode (h/j/k/l carry the current
-- window through the layout, upper-case far-moves it to an edge, `s` swaps with a picked
-- window), plus one-shot directional / far / swap commands for direct keymaps.
--
-- Moves use the proper window APIs (win_splitmove / native wincmd H-L / a buffer+view swap) —
-- never close+split, so window options and views survive. The move sub-mode is a canonical
-- modal getcharstr() loop (no timers); the moving window carries a subtle focus tint and the
-- statusline shows a "WIN MOVE" title via the lvim-hud overlay while active.
--
--   :LvimWinMove                          -- enter move mode
--   :LvimWinMove left|right|up|down        -- one-shot slide
--   :LvimWinMove far_left|far_right|far_up|far_down
--   :LvimWinMove swap                      -- pick a window and swap content with it
--   require("lvim-winmove").move("left") / .far("up") / .swap()
--
---@module "lvim-winmove"

local api = vim.api
local fn = vim.fn
local config = require("lvim-winmove.config")
local actions = require("lvim-winmove.actions")
local layout = require("lvim-winmove.layout")
local highlights = require("lvim-winmove.highlights")
local hl = require("lvim-utils.highlight")
local merge = require("lvim-utils.utils").merge

local M = {}

---@type boolean  one-time setup (highlight bind, command) done
local registered = false
local FOCUS_WH = "Normal:LvimWinMoveFocus,NormalNC:LvimWinMoveFocus"

--- Choose a swap target: lvim-winpick when present, else the first non-wall other window on the
--- tabpage (a graceful fallback so swap still works without winpick).
---@return integer? target
local function swap_target()
    local ok, winpick = pcall(require, "lvim-winpick")
    if ok then
        return winpick.pick({ include_current = false })
    end
    local cur = api.nvim_get_current_win()
    for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
        if w ~= cur and not layout.is_wall(w, config) then
            return w
        end
    end
    return nil
end

-- ── one-shot public API ──────────────────────────────────────────────────────

--- Slide the current window one slot in `dir` ("left"|"down"|"up"|"right").
---@param dir string
---@return boolean moved
function M.move(dir)
    return actions.move(dir)
end

--- Far-move the current window to the `dir` edge ("left"|"down"|"up"|"right").
---@param dir string
---@return boolean moved
function M.far(dir)
    return actions.far(dir)
end

--- Swap the current window's content with a picked (or fallback) window.
---@return boolean swapped
function M.swap()
    local target = swap_target()
    if target then
        return actions.swap(target)
    end
    return false
end

--- Swap the current window's content with a KNOWN window — the public seam for a caller that resolved the
--- target itself (lvim-winnav's directional swap resolves the neighbour and delegates here, so the exchange
--- lives in ONE place). No-op for an invalid / self target.
---@param target integer
---@return boolean swapped
function M.swap_with(target)
    return actions.swap(target)
end

-- ── interactive move mode ────────────────────────────────────────────────────

--- Build the raw-keystroke → action map for move mode from the config keys.
---@return table<string, string|fun()>
local function keymap()
    local k = config.keys
    local function tc(key)
        return api.nvim_replace_termcodes(key, true, false, true)
    end
    local km = {}
    km[tc(k.left)] = function()
        actions.move("left")
    end
    km[tc(k.down)] = function()
        actions.move("down")
    end
    km[tc(k.up)] = function()
        actions.move("up")
    end
    km[tc(k.right)] = function()
        actions.move("right")
    end
    km[tc(k.far_left)] = function()
        actions.far("left")
    end
    km[tc(k.far_down)] = function()
        actions.far("down")
    end
    km[tc(k.far_up)] = function()
        actions.far("up")
    end
    km[tc(k.far_right)] = function()
        actions.far("right")
    end
    km[tc(k.swap)] = "swap"
    for _, q in ipairs(k.quit or {}) do
        km[tc(q)] = "quit"
    end
    return km
end

--- Enter the interactive move sub-mode: h/j/k/l slide the current window, H/J/K/L far-move it,
--- `s` swaps, the quit keys leave. The moving window carries the focus tint and the statusline
--- shows a "WIN MOVE" title (via lvim-hud) while active. All state is restored on exit.
---@return nil
function M.enter()
    local focus = api.nvim_get_current_win()
    local saved_wh = vim.wo[focus].winhighlight
    vim.wo[focus].winhighlight = FOCUS_WH
    if config.hud_title then
        pcall(function()
            require("lvim-hud.overlay").set({ title = "WIN MOVE", icon = "" })
        end)
    end

    local km = keymap()
    while true do
        vim.cmd("redraw")
        local ok, ch = pcall(fn.getcharstr)
        if not ok then
            break
        end
        local action = km[ch]
        if action == "quit" then
            break
        elseif action == "swap" then
            -- Drop the focus tint while winpick owns the screen, then restore it.
            if api.nvim_win_is_valid(focus) then
                vim.wo[focus].winhighlight = saved_wh
            end
            local target = swap_target()
            if target then
                actions.swap(target)
            end
            if api.nvim_win_is_valid(focus) then
                vim.wo[focus].winhighlight = FOCUS_WH
            end
        elseif type(action) == "function" then
            action()
        end
        -- an unmapped key is ignored — you stay in move mode until a quit key
    end

    if api.nvim_win_is_valid(focus) then
        vim.wo[focus].winhighlight = saved_wh
    end
    if config.hud_title then
        pcall(function()
            require("lvim-hud.overlay").clear()
        end)
    end
    vim.cmd("redraw")
end

-- ── command ──────────────────────────────────────────────────────────────────

---@type table<string, fun()>
local DISPATCH = {
    left = function()
        M.move("left")
    end,
    right = function()
        M.move("right")
    end,
    up = function()
        M.move("up")
    end,
    down = function()
        M.move("down")
    end,
    far_left = function()
        M.far("left")
    end,
    far_right = function()
        M.far("right")
    end,
    far_up = function()
        M.far("up")
    end,
    far_down = function()
        M.far("down")
    end,
    swap = function()
        M.swap()
    end,
}

--- Merge user options into the live config, bind the focus highlight and register
--- `:LvimWinMove`. Optional — the defaults work without it.
---@param opts LvimWinMoveConfig?
---@return nil
function M.setup(opts)
    if opts then
        merge(config, opts)
    end
    if registered then
        return
    end
    registered = true

    hl.setup()
    hl.bind(highlights.build)

    api.nvim_create_user_command("LvimWinMove", function(cmd)
        local arg = cmd.args
        if arg == "" then
            M.enter()
        elseif DISPATCH[arg] then
            DISPATCH[arg]()
        else
            vim.notify("lvim-winmove: unknown argument " .. arg, vim.log.levels.WARN)
        end
    end, {
        nargs = "?",
        desc = "lvim-winmove: move mode, or a one-shot direction/swap",
        complete = function()
            return { "left", "right", "up", "down", "far_left", "far_right", "far_up", "far_down", "swap" }
        end,
    })
end

return M
