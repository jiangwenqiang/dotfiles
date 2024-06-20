local M = {}

local builtins = {
  "core.theme",
  "core.which-key",
  "core.gitsigns",
  "core.cmp",
  "core.dap",
  "core.terminal",
  "core.telescope",
  "core.treesitter",
  "core.nvimtree",
  "core.lir",
  "core.illuminate",
  "core.indentlines",
  "core.breadcrumbs",
  "core.project",
  "core.bufferline",
  "core.autopairs",
  "core.comment",
  "core.lualine",
  "core.alpha",
  "core.mason",
  "core.ufo",
  "core.xkbswitch"
}

function M.config(config)
  for _, builtin_path in ipairs(builtins) do
    local builtin = reload(builtin_path)

    builtin.config(config)
  end
end

return M
