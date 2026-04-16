-- JDTLS decompile handler for jdt:// URIs
-- Handles BufReadCmd to show decompiled class files from libraries

local M = {}

--- Load decompiled content into buffer and configure buffer options
--- @param buf integer Buffer number
--- @param content string Decompiled Java source code
--- @param client table LSP client object
local function load_buffer(buf, content, client)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, vim.split(content, "\n", { plain = true }))
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "java"
    vim.bo[buf].modifiable = false

    -- Attach LSP client for language features in decompiled buffer
    if not vim.lsp.buf_is_attached(buf, client.id) then
        vim.lsp.buf_attach_client(buf, client.id)
    end
end

--- Fallback to classFileContents when java.decompile fails
--- @param client table LSP client object
--- @param uri string jdt:// URI
--- @param buf integer Buffer number
local function try_fallback(client, uri, buf)
    local fallback = client:request_sync("java/classFileContents", { uri = uri }, 10000)
    if fallback and not fallback.err and fallback.result and fallback.result ~= "" then
        load_buffer(buf, fallback.result, client)
    else
        vim.notify("[JDTLS] Failed to decompile: " .. uri, vim.log.levels.ERROR)
    end
end

--- Setup BufReadCmd handler for jdt:// URIs
---
--- BufReadCmd requires synchronous file reading - the callback must
--- complete loading buffer content before returning. Using request_sync
--- ensures the LSP response is received before the callback returns.
---
--- @param client table LSP client object
--- @param bufnr integer Buffer number (unused, callback receives buffer from opts)
function M.setup(client, bufnr)
    local group = vim.api.nvim_create_augroup("jdtls_decompile_watcher", { clear = true })
    vim.api.nvim_create_autocmd("BufReadCmd", {
        group = group,
        pattern = "jdt://*",
        callback = function(opts)
            local uri = opts.match or opts.file
            local buf = opts.buf

            -- Try java.decompile first (preferred, gives better output)
            local result = client:request_sync("workspace/executeCommand", {
                command = "java.decompile",
                arguments = { uri },
            }, 10000)

            if result and not result.err and result.result and result.result ~= "" then
                load_buffer(buf, result.result, client)
            else
                -- Fallback to classFileContents (basic decompilation)
                try_fallback(client, uri, buf)
            end
        end,
    })
end

return M
