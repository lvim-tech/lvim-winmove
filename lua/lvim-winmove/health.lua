-- lvim-winmove: :checkhealth lvim-winmove.
-- Reports the API the move engine depends on (win_splitmove), the lvim-utils base (focus tint),
-- and the OPTIONAL integrations (lvim-winpick for swap targeting, lvim-hud for the mode title) —
-- each degrades gracefully when absent. Read-only.
--
---@module "lvim-winmove.health"

local M = {}

--- Entry point for `:checkhealth lvim-winmove`.
---@return nil
function M.check()
    local health = vim.health
    health.start("lvim-winmove")

    -- win_splitmove drives every directional move; it is core Vim, but verify it is callable.
    if vim.fn.exists("*win_splitmove") == 1 then
        health.ok("win_splitmove() available (directional moves)")
    else
        health.error("win_splitmove() missing — directional moves cannot relocate windows")
    end

    if pcall(require, "lvim-utils.colors") then
        health.ok("lvim-utils found (focus tint)")
    else
        health.error("lvim-utils not found — the move-mode focus tint is unavailable")
    end

    if pcall(require, "lvim-winpick") then
        health.ok("lvim-winpick found (swap picks a target window)")
    else
        health.info("lvim-winpick not found — swap falls back to the first other non-wall window")
    end

    if pcall(require, "lvim-hud.overlay") then
        health.ok("lvim-hud found (WIN MOVE statusline title)")
    else
        health.info("lvim-hud not found — the move-mode statusline title is skipped")
    end

    health.info("move mode reads keys via getcharstr; the quit keys (q/<Esc>/<CR>) leave it")
end

return M
