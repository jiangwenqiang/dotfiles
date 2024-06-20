local utils = require("utils")
local Log = require("core.log")

local M = {}
local user_config_dir = get_config_dir()
local user_config_file = utils.join_paths(user_config_dir, "config.lua")

---Get the full path to the user configuration file
---@return string
function M:get_user_config_path()
  return user_config_file
end

--- Initialize lvim default configuration and variables
function M:init()
  lvim = vim.deepcopy(require("config.defaults"))

  require("keymappings").load_defaults()

  local builtins = require("core.builtins")
  builtins.config({ user_config_file = user_config_file })

  local settings = require("config.settings")
  settings.load_defaults()

  local autocmds = require("core.autocmds")
  autocmds.load_defaults()

  local lvim_lsp_config = require("lsp.config")
  lvim.lsp = vim.deepcopy(lvim_lsp_config)

  lvim.builtin.luasnip = {
    sources = {
      friendly_snippets = true,
    },
  }

  lvim.builtin.bigfile = {
    active = true,
    config = {},
  }

  require("config._deprecated").handle()
end

--- Override the configuration with a user provided one
-- @param config_path The path to the configuration overrides
function M:load(config_path)
  local autocmds = reload("core.autocmds")
  config_path = config_path or self:get_user_config_path()
  local ok, err = pcall(dofile, config_path)
  if not ok then
    if utils.is_file(user_config_file) then
      vim.schedule(function()
        Log:warn("Invalid configuration: " .. err)
      end)
    else
      vim.schedule(function()
        vim.notify_once(
          string.format("User-configuration not found. Creating an example configuration in %s", config_path)
        )
      end)
      local config_name = vim.loop.os_uname().version:match "Windows" and "config_win" or "config"
      local example_config = join_paths(get_lvim_base_dir(), "utils", "installer", config_name .. ".example.lua")
      vim.fn.mkdir(user_config_dir, "p")
      vim.loop.fs_copyfile(example_config, config_path)
    end
  end

  Log:set_level(lvim.log.level)

  require("config._deprecated").post_load()

  autocmds.define_autocmds(lvim.autocommands)

  vim.g.mapleader = (lvim.leader == "space" and " ") or lvim.leader

  reload("keymappings").load(lvim.keys)

  if lvim.transparent_window then
    autocmds.enable_transparent_mode()
  end

  if lvim.reload_config_on_save then
    autocmds.enable_reload_config_on_save()
  end
end

--- Override the configuration with a user provided one
-- @param config_path The path to the configuration overrides
function M:reload()
  vim.schedule(function()
    reload("utils.hooks").run_pre_reload()

    M:load()

    reload("core.autocmds").configure_format_on_save()

    local plugins = reload("plugins")
    local plugin_loader = reload("plugin-loader")

    plugin_loader.reload { plugins, lvim.plugins }
    reload("core.theme").setup()
    reload("utils.hooks").run_post_reload()
  end)
end

return M
