local M = {}

local tbl = require("utils.table")
local Log = require("core.log")

function M.is_client_active(name)
    local clients = vim.lsp.get_clients()
    return tbl.find_first(clients, function(client)
        return client.name == name
    end)
end

function M.get_active_clients_by_ft(filetype)
    local matches = {}
    local clients = vim.lsp.get_clients()
    for _, client in pairs(clients) do
        local supported_filetypes = client.config.filetypes or {}
        if client.name ~= "null-ls" and vim.tbl_contains(supported_filetypes, filetype) then
            table.insert(matches, client)
        end
    end
    return matches
end

function M.get_client_capabilities(client_id)
    local client = vim.lsp.get_client_by_id(tonumber(client_id))
    if not client then
        Log:warn("Unable to determine client from client_id: " .. client_id)
        return
    end

    local enabled_caps = {}
    for capability, status in pairs(client.server_capabilities) do
        if status == true then
            table.insert(enabled_caps, capability)
        end
    end

    return enabled_caps
end

function M.setup_document_highlight(client, bufnr)
    if lvim.builtin.illuminate.active then
        Log:debug "skipping setup for document_highlight, illuminate already active"
        return
    end
    local status_ok, highlight_supported = pcall(function()
        return client.supports_method "textDocument/documentHighlight"
    end)
    if not status_ok or not highlight_supported then
        return
    end
    local group = "lsp_document_highlight"
    local hl_events = { "CursorHold", "CursorHoldI" }

    local ok, hl_autocmds = pcall(vim.api.nvim_get_autocmds, {
        group = group,
        buffer = bufnr,
        event = hl_events,
    })

    if ok and #hl_autocmds > 0 then
        return
    end

    vim.api.nvim_create_augroup(group, { clear = false })
    vim.api.nvim_create_autocmd(hl_events, {
        group = group,
        buffer = bufnr,
        callback = vim.lsp.buf.document_highlight,
    })
    vim.api.nvim_create_autocmd("CursorMoved", {
        group = group,
        buffer = bufnr,
        callback = vim.lsp.buf.clear_references,
    })
end

function M.setup_document_symbols(client, bufnr)
    vim.g.navic_silence = false
    local symbols_supported = client:supports_method "textDocument/documentSymbol"
    if not symbols_supported then
        Log:debug("skipping setup for document_symbols, method not supported by " .. client.name)
        return
    end
    local status_ok, navic = pcall(require, "nvim-navic")
    if status_ok then
        navic.attach(client, bufnr)
    end
end

function M.setup_codelens_refresh(client, bufnr)
    local status_ok, codelens_supported = pcall(function()
        return client:supports_method "textDocument/codeLens"
    end)
    if not status_ok or not codelens_supported then
        return
    end
    local group = "lsp_code_lens_refresh"
    local cl_events = { "BufEnter", "InsertLeave" }
    local ok, cl_autocmds = pcall(vim.api.nvim_get_autocmds, {
        group = group,
        buffer = bufnr,
        event = cl_events,
    })

    if ok and #cl_autocmds > 0 then
        return
    end
    vim.api.nvim_create_augroup(group, { clear = false })
    vim.api.nvim_create_autocmd(cl_events, {
        group = group,
        buffer = bufnr,
        callback = function()
            vim.lsp.codelens.enable(true, { bufnr = bufnr })
        end,
    })
end

---filter passed to vim.lsp.buf.format
---always selects null-ls if it's available and caches the value per buffer
---@param client table client attached to a buffer
---@return boolean if client matches
function M.format_filter(client)
    local filetype = vim.bo.filetype
    local n = require("null-ls")
    local s = require("null-ls.sources")
    local method = n.methods.FORMATTING
    local available_formatters = s.get_available(filetype, method)

    if #available_formatters > 0 then
        return client.name == "null-ls"
    elseif client.supports_method "textDocument/formatting" then
        return true
    else
        return false
    end
end

---Simple wrapper for vim.lsp.buf.format() to provide defaults
---@param opts table|nil
function M.format(opts)
    opts = opts or {}
    opts.filter = opts.filter or M.format_filter

    return vim.lsp.buf.format(opts)
end

return M
