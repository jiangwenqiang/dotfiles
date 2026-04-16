local M = {}

local Log = require("core.log")
local lvim_lsp_utils = require("lsp.utils")
local mason_lspconfig = require("mason-lspconfig")
local mason_registry = require("mason-registry")

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
  end

  -- Merge user config
  return vim.tbl_deep_extend("force", defaults, user_config or {})
end

---Check if a client is already configured for the server
---@param server_name string
---@param ft string? Filetype (optional)
---@return boolean
local function client_is_configured(server_name, ft)
  ft = ft or vim.bo.filetype
  local active_autocmds = vim.api.nvim_get_autocmds { event = "FileType", pattern = ft }

  for _, result in ipairs(active_autocmds) do
    if result.desc and result.desc:match("server " .. server_name .. " ") then
      Log:debug(string.format("[%q] is already configured", server_name))
      return true
    end
  end
  return false
end

---Setup a language server by providing a name
---@param server_name string Name of the language server
---@param user_config table? Custom configuration (optional)
function M.setup(server_name, user_config)
  -- If running in VSCode, skip LSP setup
  if vim.g.vscode then return end

  vim.validate("server_name", server_name, "string")
  -- Skip if client is active or already configured
  if lvim_lsp_utils.is_client_active(server_name) or client_is_configured(server_name) then
    Log:debug("LSP skip: " .. server_name)
    return
  end

  -- Get available servers from mason
  local available_servers = mason_lspconfig.get_available_servers()

  -- Check if server is managed by mason
  if not vim.tbl_contains(available_servers, server_name) then
    local config = resolve_config(server_name, user_config)
    vim.lsp.config(server_name,config)
    return
  end

  -- Check if auto-install is enabled for the server
  local function should_auto_install(name)
    local installer_settings = lvim.lsp.installer.setup
    return installer_settings.automatic_installation and not vim.tbl_contains(installer_settings.automatic_installation.exclude, name)
  end

  -- Get mason package name for the server
  local pkg_name = mason_lspconfig.get_mappings().lspconfig_to_package[server_name]

  -- If the server is not installed, install it automatically if enabled
  if not mason_registry.is_installed(pkg_name) then
    if should_auto_install(server_name) then
      Log:debug("Automatic server installation triggered for " .. server_name)
      vim.notify_once(string.format("Installing [%s]...", server_name), vim.log.levels.INFO)

      local pkg = mason_registry.get_package(pkg_name)
      pkg:install():once("closed", function()
        if pkg:is_installed() then
          vim.schedule(function()
            vim.notify_once(string.format("Installation complete for [%s]", server_name), vim.log.levels.INFO)
            local config = resolve_config(server_name, user_config)
            vim.lsp.config(server_name,config)
          end)
        end
      end)
    else
      Log:debug(server_name .. " is not managed by the automatic installer")
    end
  else
    -- If server is already installed, setup with resolved config
    local config = resolve_config(server_name, user_config)
    vim.lsp.config(server_name,config)
  end
end

return M
