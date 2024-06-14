local M = {}

vim.cmd [[
  function! QuickFixToggle()
    if empty(filter(getwininfo(), 'v:val.quickfix'))
      copen
    else
      cclose
    endif
  endfunction
]]

M.defaults = {
  {
    name = "BufferKill",
    fn = function()
      require("core.bufferline").buf_kill "bd"
    end,
  },
  {
    name = "NeovimToggleFormatOnSave",
    fn = function()
      require("core.autocmds").toggle_format_on_save()
    end,
  },
  {
    name = "NevimInfo",
    fn = function()
      require("core.info").toggle_popup(vim.bo.filetype)
    end,
  },
  {
    name = "NeovimCacheReset",
    fn = function()
      require("utils.hooks").reset_cache()
    end,
  },
  {
    name = "NeovimReload",
    fn = function()
      require("config"):reload()
    end,
  },
  {
    name = "NeovimUpdate",
    fn = function()
      require("bootstrap"):update()
    end,
  },
  {
    name = "NeovimSyncCorePlugins",
    fn = function()
      require("plugin-loader").sync_core_plugins()
    end,
  },
  {
    name = "NeovimChangelog",
    fn = function()
      require("core.telescope.custom-finders").view_lunarvim_changelog()
    end,
  },
  {
    name = "NeovimVersion",
    fn = function()
      print(require("utils.git").get_lvim_version())
    end,
  },
  {
    name = "NeovimOpenlog",
    fn = function()
      vim.fn.execute("edit " .. require("core.log").get_path())
    end,
  },
}

function M.load(collection)
  local common_opts = { force = true }
  if not collection then
    collection = M.defaults
  end
  for _, cmd in pairs(collection) do
    local opts = vim.tbl_deep_extend("force", common_opts, cmd.opts or {})
    vim.api.nvim_create_user_command(cmd.name, cmd.fn, opts)
  end
end

return M
