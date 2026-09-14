---The filetype ↔ language server mapping.
---
---Neovim decides whether to attach a server by *exact-matching* the buffer's filetype
---against the server's `filetypes` (see `can_start()` in `vim/lsp.lua`). So a server's own
---declaration is the source of truth, and the user's configuration only ever trims it:
---
---  declared(s)  = the server's `filetypes`, read off the runtimepath
---  effective(s) = declared(s)
---                 − all of declared(s), when s is out of scope (see M.in_scope)
---                 − all of declared(s), when s is in `skipped_servers`
---                 − every filetype listed in `skipped_filetypes`
---                 − `lvim.lsp.filetypes[ft].exclude`
---
---`lvim.lsp.filetypes[ft] = false` drops every server for that filetype.
---
---Both `vim.lsp.enable()` and the automatic installer are driven by `effective(s)`, so a
---server the user trimmed out of a filetype is neither started nor installed for it.
local M = {}

---Servers nvim-lspconfig ships a config for.
---@type string[]?
local server_names = nil

---Which servers this config may enable and install at all.
---
---Set by `lsp/manager.lua`, which owns the question -- it is the only module that knows
---about mason. Nil means "every server takes part".
---@type fun(server_name: string): boolean?
M.in_scope = nil

---The computed mapping. See M.reset().
---@type table?
local cache = nil

---Every server with a config on the runtimepath.
---@return string[]
function M.servers()
  if not server_names then
    server_names = {}
    for _, path in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
      table.insert(server_names, vim.fn.fnamemodify(path, ":t:r"))
    end
    table.sort(server_names)
  end
  return server_names
end

---The filetypes a server declares, exactly as Neovim will match them against a buffer.
---@param server_name string
---@return string[]
local function declared_filetypes(server_name)
  local ok, config = pcall(function()
    return vim.lsp.config[server_name]
  end)
  return (ok and config and config.filetypes) or {}
end

---Has the user trimmed this server out of this filetype?
---@param server_name string
---@param ft string
---@return boolean
local function is_trimmed(server_name, ft)
  local skipped = lvim.lsp.automatic_configuration
  if vim.tbl_contains(skipped.skipped_servers, server_name) then
    return true
  end
  if vim.tbl_contains(skipped.skipped_filetypes, ft) then
    return true
  end

  local rule = (lvim.lsp.filetypes or {})[ft]
  if rule == false then
    return true
  end
  return type(rule) == "table" and vim.tbl_contains(rule.exclude or {}, server_name)
end

local function build()
  local declared, effective, by_filetype, declares_filetype = {}, {}, {}, {}

  for _, server_name in ipairs(M.servers()) do
    local filetypes = declared_filetypes(server_name)
    declared[server_name] = filetypes
    effective[server_name] = {}

    -- Out of scope servers are still recorded in `declared` -- that reading of what the
    -- servers say stays faithful -- but they get no effective filetype, so nothing will
    -- ever enable or fetch them.
    local in_scope = not M.in_scope or M.in_scope(server_name)

    for _, ft in ipairs(filetypes) do
      declares_filetype[ft] = declares_filetype[ft] or {}
      table.insert(declares_filetype[ft], server_name)

      if in_scope and not is_trimmed(server_name, ft) then
        table.insert(effective[server_name], ft)
        by_filetype[ft] = by_filetype[ft] or {}
        table.insert(by_filetype[ft], server_name)
      end
    end
  end

  return {
    declared = declared,
    effective = effective,
    by_filetype = by_filetype,
    ---Untrimmed, so that M.validate() can tell a typo apart from a rule that bit.
    declares_filetype = declares_filetype,
  }
end

---@return table
local function state()
  if not cache then
    cache = build()
  end
  return cache
end

---What a server declares, before any trimming.
---@param server_name string
---@return string[]
function M.declared(server_name)
  return state().declared[server_name] or {}
end

---What a server declares, minus everything the user trimmed away.
---An empty list means the server takes no part at all: it is neither enabled nor installed.
---@param server_name string
---@return string[]
function M.effective(server_name)
  return state().effective[server_name] or {}
end

---The servers that will attach to a buffer of this filetype.
---@param ft string
---@return string[]
function M.servers_for(ft)
  return state().by_filetype[ft] or {}
end

---Trim rules that matched nothing, which is nearly always a typo or a renamed server.
---@return string[] complaints, empty when the configuration is sound
function M.validate()
  local declares = state().declares_filetype
  local complaints = {}

  for ft, rule in pairs(lvim.lsp.filetypes or {}) do
    if not declares[ft] then
      table.insert(complaints, string.format(".filetypes.%s: no server declares this filetype", ft))
    elseif type(rule) == "table" then
      for _, server_name in ipairs(rule.exclude or {}) do
        if not vim.tbl_contains(declares[ft], server_name) then
          table.insert(complaints, string.format(".filetypes.%s.exclude: %q does not declare it", ft, server_name))
        end
      end
    end
  end

  table.sort(complaints)
  return complaints
end

---Forget the computed mapping, e.g. after the user's configuration changed.
function M.reset()
  cache = nil
end

return M
