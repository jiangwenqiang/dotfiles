local opts = {
  root_dir = function(fname)
    local util = require("lspconfig/util")
    return util.root_pattern(
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
  end,
}

return opts
