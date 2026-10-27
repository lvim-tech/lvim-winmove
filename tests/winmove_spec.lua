-- Walls, adjacency, and what a rearrange is allowed to cost the rest of the screen.
--
-- Two ideas do the work here:
--
-- 1. a WALL is a window a move may never displace into, and may never be: an excluded buffer
--    or a size-fixed panel. Both ends are checked, because flinging a 30-column sidebar at a
--    screen edge is as wrong as landing on top of it;
-- 2. a rearrange must not quietly resize the rest of the tab. Walls are pinned in the one
--    dimension they own, and the tab is equalised afterwards. The second half matters only
--    when 'equalalways' is off -- and that is exactly when it matters a great deal, which is
--    the one case here that is set up with 'equalalways' off deliberately.

local actions = require("lvim-winmove.actions")
local layout = require("lvim-winmove.layout")
local config = require("lvim-winmove.config")

--- Give `win` a buffer of its OWN. A plain `:vsplit` shows the SAME buffer in both windows, so
--- a filetype set for one window would make every window a wall -- which is how the first
--- version of this spec managed to measure nothing at all.
---@param win integer
---@param ft string
---@param nlines? integer
---@return integer buf
local function own_buffer(win, ft, nlines)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.bo[buf].filetype = ft
    local lines = {}
    for i = 1, (nlines or 1) do
        lines[i] = "line " .. i
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_win_set_buf(win, buf)
    return buf
end

--- A 30-column sidebar on the left (an excluded filetype, so a wall by its buffer alone and
--- NOT by any winfix option), and an editing window beside it.
---@return integer side
---@return integer main
local function sidebar_and_main()
    vim.cmd("silent! only")
    local main = vim.api.nvim_get_current_win()
    own_buffer(main, "lua")
    vim.cmd("topleft vsplit")
    local side = vim.api.nvim_get_current_win()
    own_buffer(side, "lvim-files")
    vim.api.nvim_win_set_width(side, 30)
    vim.api.nvim_set_current_win(main)
    return side, main
end

describe("lvim-winmove: what counts as a wall")

it("an excluded filetype is a wall, a plain buffer is not", function()
    local side, main = sidebar_and_main()
    eq(true, layout.is_wall(side, config))
    eq(false, layout.is_wall(main, config))
end)

it("an excluded buftype is a wall", function()
    vim.cmd("silent! only")
    local win = vim.api.nvim_get_current_win()
    local buf = own_buffer(win, "")
    vim.bo[buf].buftype = "quickfix"
    eq(true, layout.is_wall(win, config))
    vim.bo[buf].buftype = ""
    eq(false, layout.is_wall(win, config))
end)

it("a size-fixed window is a wall whichever dimension is fixed", function()
    vim.cmd("silent! only")
    local win = vim.api.nvim_get_current_win()
    own_buffer(win, "lua")
    vim.wo[win].winfixwidth = true
    eq(true, layout.is_wall(win, config))
    vim.wo[win].winfixwidth = false
    vim.wo[win].winfixheight = true
    eq(true, layout.is_wall(win, config))
    vim.wo[win].winfixheight = false
end)

it("a window that no longer exists is a wall", function()
    eq(true, layout.is_wall(999999, config), "nothing may be moved into a window that is gone")
end)

describe("lvim-winmove: adjacency is Vim's own")

it("a neighbour is resolved in each direction, and is nil at the edge", function()
    local side, main = sidebar_and_main()
    eq(side, layout.neighbour(main, "left"))
    eq(main, layout.neighbour(side, "right"))
    eq(nil, layout.neighbour(side, "left"), "the leftmost window has nothing to its left")
    eq(nil, layout.neighbour(main, "right"))
end)

it("up and down resolve in a stack", function()
    vim.cmd("silent! only")
    local bottom = vim.api.nvim_get_current_win()
    own_buffer(bottom, "lua")
    vim.cmd("split")
    local top = vim.api.nvim_get_current_win()
    own_buffer(top, "lua")
    eq(bottom, layout.neighbour(top, "down"))
    eq(top, layout.neighbour(bottom, "up"))
    eq(nil, layout.neighbour(top, "up"))
end)

it("a direction that does not exist has no neighbour", function()
    sidebar_and_main()
    eq(nil, layout.neighbour(vim.api.nvim_get_current_win(), "sideways"))
end)

describe("lvim-winmove: a move refuses rather than breaking the layout")

it("a move into a wall does nothing", function()
    local side, main = sidebar_and_main()
    local before = vim.fn.winlayout()
    eq(false, actions.move("left"), "the left neighbour is the sidebar")
    eq(before, vim.fn.winlayout())
    eq(30, vim.api.nvim_win_get_width(side))
end)

it("a move at the edge does nothing", function()
    sidebar_and_main()
    local before = vim.fn.winlayout()
    eq(false, actions.move("right"), "there is nothing to the right")
    eq(before, vim.fn.winlayout())
end)

it("a wall itself is never moved, near or far", function()
    local side = sidebar_and_main()
    vim.api.nvim_set_current_win(side)
    local before = vim.fn.winlayout()
    eq(false, actions.move("right"))
    eq(false, actions.far("right"))
    eq(before, vim.fn.winlayout(), "a sidebar stays a sidebar")
end)

it("a far-move relocates the window and leaves the wall its width", function()
    local side, main = sidebar_and_main()
    vim.api.nvim_set_current_win(main)
    vim.cmd("split")
    local second = vim.api.nvim_get_current_win()
    own_buffer(second, "lua")

    eq(true, actions.far("down"))
    eq(80, vim.api.nvim_win_get_width(second), "the far-moved window spans the screen")
    eq(30, vim.api.nvim_win_get_width(side), "a window leaving a row must not hand its width to the wall")
end)

describe("lvim-winmove: equalising after a move")

it("without equalising, a far-move leaves the rest of the tab one row", function()
    -- This is the whole reason the `equalize` option exists, and it is only visible with
    -- 'equalalways' off -- with it on, Vim equalises the tab itself and the two settings look
    -- identical. So: measured with 'equalalways' off, both ways.
    local was_ea = vim.o.equalalways
    local was_eq = config.equalize
    vim.o.equalalways = false

    ---@param equalize boolean
    ---@return integer[] heights
    local function far_down_with(equalize)
        vim.cmd("silent! only")
        local first = vim.api.nvim_get_current_win()
        own_buffer(first, "lua")
        vim.cmd("vsplit")
        local second = vim.api.nvim_get_current_win()
        own_buffer(second, "lua")
        vim.api.nvim_win_set_width(second, 20)
        config.equalize = equalize
        vim.api.nvim_set_current_win(second)
        eq(true, actions.far("down"))
        local heights = {}
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            heights[#heights + 1] = vim.api.nvim_win_get_height(w)
        end
        table.sort(heights)
        return heights
    end

    local without = far_down_with(false)
    local with = far_down_with(true)

    vim.o.equalalways = was_ea
    config.equalize = was_eq

    eq(1, without[1], "the moved window kept its full height and starved the other one")
    truthy(with[1] > 1, "equalising shares the screen: got " .. vim.inspect(with))
    truthy(math.abs(with[1] - with[2]) <= 1, "and shares it evenly: got " .. vim.inspect(with))
end)

describe("lvim-winmove: a swap exchanges content, not position")

it("the buffers trade places and each view follows its buffer", function()
    vim.cmd("silent! only")
    local a = vim.api.nvim_get_current_win()
    local abuf = own_buffer(a, "lua", 200)
    vim.cmd("split")
    local b = vim.api.nvim_get_current_win()
    local bbuf = own_buffer(b, "lua", 200)

    vim.api.nvim_win_set_cursor(a, { 150, 0 })
    vim.api.nvim_win_call(a, function()
        vim.cmd("normal! zt")
    end)
    vim.api.nvim_win_set_cursor(b, { 5, 0 })
    local view_a = vim.api.nvim_win_call(a, vim.fn.winsaveview)

    vim.api.nvim_set_current_win(a)
    eq(true, actions.swap(b))

    eq(bbuf, vim.api.nvim_win_get_buf(a))
    eq(abuf, vim.api.nvim_win_get_buf(b))
    local view_b_now = vim.api.nvim_win_call(b, vim.fn.winsaveview)
    eq(view_a.topline, view_b_now.topline, "the view travels with the buffer, not with the window")
    eq(view_a.lnum, view_b_now.lnum)
end)

it("a swap with itself, or with a window that is gone, is refused", function()
    vim.cmd("silent! only")
    local win = vim.api.nvim_get_current_win()
    own_buffer(win, "lua")
    eq(false, actions.swap(win))
    eq(false, actions.swap(999999))
    eq(false, actions.swap(nil))
end)
