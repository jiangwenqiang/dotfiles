local M = {}

local Log = require("core.log")
local filetypes = require("lsp.filetypes")
local mason_lspconfig = require("mason-lspconfig")
local mason_registry = require("mason-registry")

---Servers already handed to `vim.lsp.config()` + `vim.lsp.enable()`.
---@type table<string, boolean>
local enabled = {}

---Servers with an install currently in flight.
---@type table<string, boolean>
local installing = {}

local did_setup = false

---Resolve the configuration for a server by merging with the default config
---@param server_name string
---@param user_config table? Optional user configuration
---@return table
local function resolve_config(server_name, user_config)
  local defaults = {
    on_attach = require("lsp").common_on_attach,
    on_init = require("lsp").common_on_init,
    on_exit = require("lsp").common_on_exit,
    capabilities = require("lsp").common_capabilities(),
  }

  -- Custom configuration (if available)
  local has_custom_provider, custom_config = pcall(require, "lsp/providers/" .. server_name)
  if has_custom_provider then
    defaults = vim.tbl_deep_extend("force", defaults, custom_config)
  elseif #vim.api.nvim_get_runtime_file("lua/lsp/providers/" .. server_name .. ".lua", false) > 0 then
    -- The provider exists but failed to load. Providers do real work at require time
    -- (jdtls, for one, errors when there is no Java 21 runtime), and swallowing that
    -- would resurface as a confusing "executable not found" much later.
    Log:error(string.format("Failed to load lsp/providers/%s: %s", server_name, custom_config))
    vim.notify(
      string.format("Failed to load [%s] provider: %s", server_name, custom_config),
      vim.log.levels.ERROR
    )
  end

  -- Merge user config
  return vim.tbl_deep_extend("force", defaults, user_config or {})
end

---The mason package that ships this server, if there is one.
---@param server_name string
---@return string?
local function package_name(server_name)
  return mason_lspconfig.get_mappings().lspconfig_to_package[server_name]
end

---Is this a server the automatic machinery may enable and install?
---
---Only mason-shipped servers are, which is the boundary this config has always drawn:
---mason-lspconfig's `automatic_enable` iterates `lspconfig_to_package` and nothing else.
---Of the 392 servers nvim-lspconfig defines, 112 have no package here. Taking "no package"
---to mean "installed" attaches every one of them to every buffer of any filetype it
---declares. Most die on a missing executable, but a few do not -- `gitlab_duo` is `npx`,
---`turtle_ls` is `node`, `tvm_ffi_navigator` is `python` -- and those really do get
---spawned. Enabling a server mason does not ship is a deliberate act, not a default.
---@param server_name string
---@return boolean
function M.is_managed(server_name)
  return package_name(server_name) ~= nil
end

---Has mason already installed this server? Unmanaged servers are never installed.
---@param server_name string
---@return boolean
function M.is_installed(server_name)
  local pkg_name = package_name(server_name)
  if not pkg_name then
    return false
  end
  local ok, installed = pcall(mason_registry.is_installed, pkg_name)
  return ok and installed
end

---Hand a server to Neovim, which then attaches it to matching buffers by itself.
---@param server_name string
---@param effective_filetypes string[]
local function activate(server_name, effective_filetypes)
  if enabled[server_name] then
    return
  end

  local config = resolve_config(server_name, nil)
  if #effective_filetypes ~= #filetypes.declared(server_name) then
    -- The user trimmed something. `vim.lsp.config()` replaces array values instead of
    -- merging them, so this replaces the whole list rather than patching it.
    config.filetypes = effective_filetypes
  end

  local ok, err = pcall(vim.lsp.config, server_name, config)
  if ok then
    ok, err = pcall(vim.lsp.enable, server_name)
  end
  if not ok then
    Log:error(string.format("Failed to enable %s: %s", server_name, err))
    vim.notify(string.format("Failed to enable [%s]: %s", server_name, err), vim.log.levels.ERROR)
    return
  end

  enabled[server_name] = true
  Log:debug("Enabled " .. server_name)
end

---Install a server, then enable it.
---@param server_name string
local function install(server_name)
  if enabled[server_name] or installing[server_name] then
    return
  end

  local pkg_name = package_name(server_name)
  if not pkg_name then
    vim.notify(
      string.format("[%s] is not installed and mason has no package for it", server_name),
      vim.log.levels.WARN
    )
    return
  end

  local ok, package = pcall(mason_registry.get_package, pkg_name)
  if not ok then
    vim.notify(
      string.format("Cannot install [%s]: mason has no package named %s", server_name, pkg_name),
      vim.log.levels.ERROR
    )
    return
  end

  installing[server_name] = true
  Log:debug("Automatic server installation triggered for " .. server_name)
  vim.notify_once(string.format("Installing [%s]...", server_name), vim.log.levels.INFO)

  package:install():once("closed", function()
    vim.schedule(function()
      installing[server_name] = nil
      if not package:is_installed() then
        vim.notify(
          string.format("Failed to install [%s], see :MasonLog", server_name),
          vim.log.levels.ERROR
        )
        return
      end
      vim.notify_once(string.format("Installation complete for [%s]", server_name), vim.log.levels.INFO)
      -- Recomputed rather than reused: the configuration may have moved on meanwhile.
      activate(server_name, filetypes.effective(server_name))
    end)
  end)
end

---Enable every installed server that has filetypes left after trimming, and arrange for
---the others to be installed the first time a file of one of those filetypes is opened.
function M.setup()
  if did_setup or vim.g.vscode then
    return
  end
  did_setup = true

  -- Draw the boundary before anything reads the mapping: servers mason does not ship take
  -- no part in it. See `M.is_managed`.
  filetypes.in_scope = M.is_managed
  filetypes.reset()

  for _, complaint in ipairs(filetypes.validate()) do
    vim.notify("lvim.lsp" .. complaint, vim.log.levels.WARN)
  end

  ---Servers that are not installed yet, grouped by the filetype that would need them.
  ---@type table<string, string[]>
  local pending = {}

  for _, server_name in ipairs(filetypes.servers()) do
    -- Out of scope and trimmed-out servers both come back with no effective filetype, so
    -- neither can be queued for an install that would never happen.
    local effective = filetypes.effective(server_name)
    if #effective > 0 then
      if M.is_installed(server_name) then
        activate(server_name, effective)
      else
        for _, ft in ipairs(effective) do
          pending[ft] = pending[ft] or {}
          table.insert(pending[ft], server_name)
        end
      end
    end
  end

  if next(pending) == nil then
    return
  end

  -- Installing waits for a file of that type to actually be opened, which is what makes
  -- trimming a server out of a filetype mean it never gets installed either.
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("LvimLspAutomaticInstall", { clear = true }),
    callback = function(args)
      for _, server_name in ipairs(pending[args.match] or {}) do
        install(server_name)
      end
    end,
  })
end

return M
