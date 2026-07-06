-- lvim-winmove.highlights: the move-mode focus tint.
-- LvimWinMoveFocus is a SUBTLE whole-window background tint (mtint(yellow, 0.15)) applied to
-- the window being moved while the mode is active, so it is obvious which window hjkl carries.
-- build() reads the live palette; bound via lvim-utils.highlight.bind in init so it re-derives
-- on ColorScheme / palette sync.
--
---@module "lvim-winmove.highlights"

local c = require("lvim-utils.colors")
local hl = require("lvim-utils.highlight")

local M = {}

--- The focus-window highlight from the live palette.
---@return table<string, table>
function M.build()
    return {
        LvimWinMoveFocus = { bg = hl.blend(c.yellow, c.bg, 0.15) },
    }
end

return M
