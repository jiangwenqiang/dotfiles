---@diagnostic disable: deprecated
local M = {}

local function deprecate(name, alternative)
  local in_headless = #vim.api.nvim_list_uis() == 0
  if in_headless then
    return
  end

  alternative = alternative or "See https://github.com/Neovim/Neovim#breaking-changes"

  local trace = debug.getinfo(3, "Sl")
  local shorter_src = trace.short_src
  local t = shorter_src .. ":" .. (trace.currentline or trace.lastlinedefined)
  vim.schedule(function()
    vim.notify_once(string.format("%s: `%s` is deprecated.\n %s.", t, name, alternative), vim.log.levels.WARN)
  end)
end

function M.handle()
  local mt = {
    __newindex = function(_, k, _)
      deprecate(k)
    end,
  }

  ---@deprecated
  lvim.builtin.theme.options = {}
  setmetatable(lvim.builtin.theme.options, {
    __newindex = function(_, k, v)
      deprecate("lvim.builtin.theme.options." .. k, "Use `lvim.builtin.theme.<theme>.options` instead")
      lvim.builtin.theme.tokyonight.options[k] = v
    end,
  })

  ---@deprecated
  lvim.builtin.notify = {}
  setmetatable(lvim.builtin.notify, {
    __newindex = function(_, k, _)
      deprecate("lvim.builtin.notify." .. k, "See Neovim#3294")
    end,
  })

  ---@deprecated
  lvim.builtin.dashboard = {}
  setmetatable(lvim.builtin.dashboard, {
    __newindex = function(_, k, _)
      deprecate("lvim.builtin.dashboard." .. k, "Use `lvim.builtin.alpha` instead. See Neovim#1906")
    end,
  })

  ---@deprecated
  lvim.lsp.popup_border = {}
  setmetatable(lvim.lsp.popup_border, mt)

  ---@deprecated
  lvim.lsp.float = {}
  setmetatable(lvim.lsp.float, {
    __newindex = function(_, k, _)
      deprecate("lvim.lsp.float." .. k, "Use options provided by the handler instead")
    end,
  })

  ---@deprecated
  lvim.lsp.diagnostics = {}
  setmetatable(lvim.lsp.diagnostics, {
    __newindex = function(table, k, v)
      deprecate("lvim.lsp.diagnostics." .. k, string.format("Use `vim.diagnostic.config({ %s = %s })` instead", k, v))
      rawset(table, k, v)
    end,
  })

  ---@deprecated
  lvim.lang = {}
  setmetatable(lvim.lang, mt)
end

function M.post_load()
  if lvim.lsp.diagnostics and not vim.tbl_isempty(lvim.lsp.diagnostics) then
    vim.diagnostic.config(lvim.lsp.diagnostics)
  end

  if lvim.lsp.override and not vim.tbl_isempty(lvim.lsp.override) then
    deprecate("lvim.lsp.override", "Use `lvim.lsp.automatic_configuration.skipped_servers` instead")
    vim.tbl_map(function(c)
      if not vim.tbl_contains(lvim.lsp.automatic_configuration.skipped_servers, c) then
        table.insert(lvim.lsp.automatic_configuration.skipped_servers, c)
      end
    end, lvim.lsp.override)
  end

  if lvim.autocommands.custom_groups then
    deprecate(
      "lvim.autocommands.custom_groups",
      "Use vim.api.nvim_create_autocmd instead or check Neovim#2592 to learn about the new syntax"
    )
  end

  if lvim.lsp.automatic_servers_installation then
    deprecate(
      "lvim.lsp.automatic_servers_installation",
      "Use `lvim.lsp.installer.setup.automatic_installation` instead"
    )
  end

  local function convert_spec_to_lazy(spec)
    local alternatives = {
      setup = "init",
      as = "name",
      opt = "lazy",
      run = "build",
      lock = "pin",
      requires = "dependencies",
    }

    alternatives.tag = function()
      if spec.tag == "*" then
        spec.version = "*"
        return [[version = "*"]]
      end
    end

    alternatives.disable = function()
      if type(spec.disabled) == "function" then
        spec.enabled = function()
          return not spec.disabled()
        end
      else
        spec.enabled = not spec.disabled
      end
      return "enabled = " .. vim.inspect(spec.enabled)
    end

    alternatives.wants = function()
      return "dependencies = [value]"
    end
    alternatives.needs = alternatives.wants

    alternatives.module = function()
      spec.lazy = true
      return "lazy = true"
    end

    for old_key, alternative in pairs(alternatives) do
      if spec[old_key] ~= nil then
        local message
        local old_value = vim.inspect(spec[old_key]) or "value"

        if type(alternative) == "function" then
          message = alternative()
        else
          spec[alternative] = spec[old_key]
        end

        -- not every function in alternatives returns a message (e.g. tag)
        if type(alternative) ~= "function" or message then
          spec[old_key] = nil

          local new_value = vim.inspect(spec[alternative] or "[value]")
          message = message or string.format("%s = %s", alternative, new_value)
          vim.schedule(function()
            vim.notify_once(
              string.format(
                [[`%s = %s` in `lvim.plugins` has been deprecated since the migration to lazy.nvim. Use `%s` instead.
Example:
`lvim.plugins = {... {... %s = %s ...} ...}`
->
`lvim.plugins = {... {... %s ...} ...}`
See https://github.com/folke/lazy.nvim#-migration-guide"]],
                old_key,
                old_value,
                message,
                old_key,
                old_value,
                message
              ),
              vim.log.levels.WARN
            )
          end)
        end
      end
    end

    if spec[1] and spec[1]:match "^http" then
      spec.url = spec[1]
      spec[1] = nil

      vim.schedule(function()
        vim.notify_once(

          string.format(
            [[`"http..."` in `lvim.plugins` has been deprecated since the migration to lazy.nvim. Use `url = "http..."` instead.
Example:
`lvim.plugins = {... { "%s" ...} ...}`
->
`lvim.plugins = {... { url = "%s" ...} ...}`
See https://github.com/folke/lazy.nvim#-migration-guide"]],
            spec.url,
            spec.url
          ),

          vim.log.levels.WARN
        )
      end)
    end
  end

  for _, plugin in ipairs(lvim.plugins) do
    if type(plugin) == "table" then
      convert_spec_to_lazy(plugin)
    end
  end
end

return M
