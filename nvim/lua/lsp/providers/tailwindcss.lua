local opts = {
  -- `vim.lsp.config` calls a function `root_dir` as `root_dir(bufnr, on_dir)` and
  -- discards its return value -- only calling `on_dir` reaches `start_config`. This
  -- file used to *return* the path, so the client was never started, in any of
  -- tailwindcss's 60 filetypes. Kept in the callback shape upstream uses.
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local util = require("lspconfig/util")
    on_dir(
      util.root_pattern(
            "tailwind.config.js",
            "tailwind.config.ts",
            "tailwind.config.cjs",
            "tailwind.js",
            "tailwind.ts",
            "tailwind.cjs"
          )(fname)
        or util.find_package_json_ancestor(fname)
        or util.find_node_modules_ancestor(fname)
        or util.find_git_ancestor(fname)
    )
  end,
}

return opts
