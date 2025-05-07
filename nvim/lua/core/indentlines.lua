local M = {}

M.config = function()
  lvim.builtin.indentlines = {
    active = true,
    on_config_done = nil,
    -- options = {
    --   enabled = true,
    --   buftype_exclude = { "terminal", "nofile" },
    --   filetype_exclude = {
    --     "help",
    --     "startify",
    --     "dashboard",
    --     "lazy",
    --     "neogitstatus",
    --     "NvimTree",
    --     "Trouble",
    --     "text",
    --   },
    --   char = lvim.icons.ui.LineLeft,
    --   context_char = lvim.icons.ui.LineLeft,
    --   show_trailing_blankline_indent = false,
    --   show_first_indent_level = true,
    --   use_treesitter = true,
    --   show_current_context = true,
    -- },
    options = {
      -- 基础开关
      enabled = true,
      -- 排除规则
      exclude = {
        buftypes = { "terminal", "nofile" },
        filetypes = {
          "help", "startify", "dashboard", "lazy",
          "neogitstatus", "NvimTree", "Trouble", "text",
        },
      },
      -- 缩进线样式
      indent = {
        char = lvim.icons.ui.LineLeft,                           -- 缩进字符（保持与 2.x 一致）
        highlight = "IblIndent",                                 -- 3.x 需要显式指定高亮组
        smart_indent_cap = true,
      },
      -- 作用域和上下文
      scope = {
        enabled = true,     -- 显式启用作用域高亮
        show_start = false, -- 根据需求调整
        show_end = false,
      },
    }
  }
end

M.setup = function()
  local status_ok, indent_blankline = pcall(require, "ibl")
  if not status_ok then
    return
  end

  indent_blankline.setup(lvim.builtin.indentlines.options)

  if lvim.builtin.indentlines.on_config_done then
    lvim.builtin.indentlines.on_config_done()
  end
end

return M
