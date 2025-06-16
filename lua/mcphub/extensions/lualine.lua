--[[
--NOTE: Having cmd = "MCPHub" or lazy = true in user's lazy config, and adding lualine component using require("mcphub.extensions.lualine") will start the hub indirectly.
--]]
local M = require("lualine.component"):extend()
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_interval = 80 -- ms between frames
local timer = nil
local current_frame = 1

M.HubState = {
    STARTING = "starting",
    READY = "ready",
    ERROR = "error",
    RESTARTING = "restarting",
    RESTARTED = "restarted",
    STOPPED = "stopped",
    STOPPING = "stopping",
}

vim.g.mcphub_status = M.HubState.STARTING
-- Initialize the component
function M:init(options)
    M.super.init(self, options)
    self:create_autocommands()
end

function M:create_autocommands()
    local group = vim.api.nvim_create_augroup("mcphub_lualine", { clear = true })

    -- Handle state changes
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "MCPHubStateChange",
        callback = function(args)
            self:manage_spinner()
            if args.data then
                vim.g.mcphub_status = args.data.state
                vim.g.mcphub_active_servers = args.data.active_servers
            end
        end,
    })

    -- Tool/Resource activity events
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = { "MCPHub*" },
        callback = function(args)
            -- Update based on event pattern
            if args.match == "MCPHubToolStart" then
                vim.g.mcphub_executing = true
                vim.g.mcphub_tool_active = true
                vim.g.mcphub_tool_info = args.data
            elseif args.match == "MCPHubToolEnd" then
                vim.g.mcphub_executing = false
                vim.g.mcphub_tool_active = false
                vim.g.mcphub_tool_info = nil
            elseif args.match == "MCPHubResourceStart" then
                vim.g.mcphub_executing = true
                vim.g.mcphub_resource_active = true
                vim.g.mcphub_resource_info = args.data
            elseif args.match == "MCPHubResourceEnd" then
                vim.g.mcphub_executing = false
                vim.g.mcphub_resource_active = false
                vim.g.mcphub_resource_info = nil
            elseif args.match == "MCPHubPromptStart" then
                vim.g.mcphub_executing = true
                vim.g.mcphub_prompt_active = true
                vim.g.mcphub_prompt_info = args.data
            elseif args.match == "MCPHubPromptEnd" then
                vim.g.mcphub_executing = false
                vim.g.mcphub_prompt_active = false
                vim.g.mcphub_prompt_info = nil
            end
            -- Manage animation
            self:manage_spinner()
        end,
    })
end

function M.is_connected()
    return vim.g.mcphub_status == M.HubState.READY or vim.g.mcphub_status == M.HubState.RESTARTED
end

function M.is_connecting()
    return vim.g.mcphub_status == M.HubState.STARTING or vim.g.mcphub_status == M.HubState.RESTARTING
end

function M:manage_spinner()
    local should_show = vim.g.mcphub_executing and M.is_connected()
    if should_show and not timer then
        timer = vim.loop.new_timer()
        if timer then
            timer:start(
                0,
                spinner_interval,
                vim.schedule_wrap(function()
                    current_frame = (current_frame % #spinner_frames) + 1
                    vim.cmd("redrawstatus")
                end)
            )
        end
    elseif not should_show and timer then
        timer:stop()
        timer:close()
        timer = nil
        current_frame = 1
    end
end

-- Get appropriate status icon and highlight
function M:get_status_display()
    local tower = "󰐻"
    return tower, M.is_connected() and "DiagnosticInfo" or M.is_connecting() and "DiagnosticWarn" or "DiagnosticError"
end

-- Format with highlight
function M:format_hl(text, hl)
    if hl then
        return string.format("%%#%s#%s%%*", hl, text)
    end
    return text
end

-- Update function that lualine calls
function M:update_status()
    -- Get status display
    -- local status_icon, status_hl = self:get_status_display()

    -- Show either the spinner or the number of active servers
    local count_or_spinner = vim.g.mcphub_executing and spinner_frames[current_frame]
        or tostring(vim.g.mcphub_active_servers or 0)
    -- Format the status line
    -- return self:format_hl(status_icon .. " " .. count_or_spinner .. " ", status_hl)
    local tower = "󰐻"
    return tower .. " " .. count_or_spinner
end

-- Cleanup
function M:disable()
    if timer then
        timer:stop()
        timer:close()
        timer = nil
    end
end

return M
