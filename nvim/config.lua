-- user neovim config file
vim.o.relativenumber = true

-- Fix ESC+j\k swap lines
lvim.keys.insert_mode["<A-j>"] = false
lvim.keys.insert_mode["<A-k>"] = false
lvim.keys.normal_mode["<A-j>"] = false
lvim.keys.normal_mode["<A-k>"] = false
lvim.keys.visual_block_mode["<A-j>"] = false
lvim.keys.visual_block_mode["<A-k>"] = false
lvim.keys.visual_block_mode["J"] = false
lvim.keys.visual_block_mode["K"] = false

-- add your own keymappin
lvim.keys.normal_mode["<C-s>"] = ":w<cr>"
lvim.keys.normal_mode["gh"] = "g^"
lvim.keys.normal_mode["gl"] = "g$"
lvim.keys.normal_mode["H"] = "<cmd>BufferLineCyclePrev<cr>"
lvim.keys.normal_mode["L"] = "<cmd>BufferLineCycleNext<cr>"

-- nvimtree ignore directories
lvim.builtin.nvimtree.setup.filters.custom = {
  "node_modules", "\\.cache", "\\.git", "\\.venv", "\\.idea", "\\.DS_Store"
}
