local M = {}

if vim.fn.has "nvim-0.10" ~= 1 then
  vim.notify("Please upgrade your Neovim base installation. neovim requires v0.10+", vim.log.levels.WARN)
  vim.wait(5000, function()
    ---@diagnostic disable-next-line: redundant-return-value
    return false
  end)
  vim.cmd "cquit"
end

local uv = vim.loop
local path_sep = uv.os_uname().version:match "Windows" and "\\" or "/"

---Join path segments that were passed as input
---@return string
function _G.join_paths(...)
  local result = table.concat({ ... }, path_sep)
  return result
end

_G.require_clean = require("utils.modules").require_clean
_G.require_safe = require("utils.modules").require_safe
_G.reload = require("utils.modules").reload

---Get the full path to `$NEOVIM_RUNTIME_DIR`
---@return string|nil
function _G.get_runtime_dir()
  local lvim_runtime_dir = os.getenv "NEOVIM_RUNTIME_DIR"
  if not lvim_runtime_dir then
    -- when nvim is used directly
    return vim.call("stdpath", "data")
  end
  return lvim_runtime_dir
end

---Get the full path to `$NEOVIM_CONFIG_DIR`
---@return string|nil
function _G.get_config_dir()
  local lvim_config_dir = os.getenv "NEOVIM_CONFIG_DIR"
  if not lvim_config_dir then
    return vim.call("stdpath", "config")
  end
  return lvim_config_dir
end

---Get the full path to `$NEOVIM_CACHE_DIR`
---@return string|nil
function _G.get_cache_dir()
  local lvim_cache_dir = os.getenv "NEOVIM_CACHE_DIR"
  if not lvim_cache_dir then
    return vim.call("stdpath", "cache")
  end
  return lvim_cache_dir
end

---Initialize the `&runtimepath` variables and prepare for startup
---@return table
function M:init(base_dir)
  self.runtime_dir = get_runtime_dir()
  self.config_dir = get_config_dir()
  self.cache_dir = get_cache_dir()
  self.pack_dir = join_paths(self.runtime_dir, "site", "pack")
  self.lazy_install_dir = join_paths(self.pack_dir, "lazy", "opt", "lazy.nvim")

  ---@meta overridden to use NEOVIM_CACHE_DIR instead, since a lot of plugins call this function internally
  ---NOTE: changes to "data" are currently unstable, see #2507
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.fn.stdpath = function(what)
    if what == "cache" then
      return _G.get_cache_dir()
    end
    return vim.call("stdpath", what)
  end

  ---Get the full path to Neovim's base directory
  ---@return string
  function _G.get_lvim_base_dir()
    local _base_dir = base_dir
    if not _base_dir then
      _base_dir = self.config_dir
    end
    return _base_dir
  end

  if os.getenv "NEOVIM_RUNTIME_DIR" then
    vim.opt.rtp:remove(join_paths(vim.call("stdpath", "data"), "site"))
    vim.opt.rtp:remove(join_paths(vim.call("stdpath", "data"), "site", "after"))
    -- vim.opt.rtp:prepend(join_paths(self.runtime_dir, "site"))
    vim.opt.rtp:append(join_paths(self.runtime_dir, "lvim", "after"))
    vim.opt.rtp:append(join_paths(self.runtime_dir, "site", "after"))

    vim.opt.rtp:remove(vim.call("stdpath", "config"))
    vim.opt.rtp:remove(join_paths(vim.call("stdpath", "config"), "after"))
    vim.opt.rtp:prepend(self.config_dir)
    vim.opt.rtp:append(join_paths(self.config_dir, "after"))

    vim.opt.packpath = vim.opt.rtp:get()
  end

  -- init lazy plugin
  require("plugin-loader").init({
    package_root = self.pack_dir,
    install_path = self.lazy_install_dir,
  })

  -- load config/init.lua & config.lua
  require("config"):init()

  -- load mason
  require("core.mason").bootstrap()

  return self
end

---Update Neovim
---pulls the latest changes from github and, resets the startup cache
function M:update()
  require("core.log"):info "Trying to update Neovim..."

  vim.schedule(function()
    reload("utils.hooks").run_pre_update()
    local ret = reload("utils.git").update_base_lvim()
    if ret then
      reload("utils.hooks").run_post_update()
    end
  end)
end

return M
