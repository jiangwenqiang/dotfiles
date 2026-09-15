-- user neovim config file
vim.o.relativenumber = true
vim.opt.mouse = ""
vim.opt.winborder = "single"

-- Fix ESC+j\k swap lines
-- lvim.keys.insert_mode["<A-j>"] = false
-- lvim.keys.insert_mode["<A-k>"] = false
-- lvim.keys.normal_mode["<A-j>"] = false
-- lvim.keys.normal_mode["<A-k>"] = false
-- lvim.keys.visual_block_mode["<A-j>"] = false
-- lvim.keys.visual_block_mode["<A-k>"] = false
-- lvim.keys.visual_block_mode["J"] = false
-- lvim.keys.visual_block_mode["K"] = false

-- add your own keymappin
lvim.keys.normal_mode["<C-s>"] = ":w<cr>"
lvim.keys.normal_mode["gh"] = "g^"
lvim.keys.normal_mode["gl"] = "g$"
lvim.keys.normal_mode["H"] = "<cmd>BufferLineCyclePrev<cr>"
lvim.keys.normal_mode["L"] = "<cmd>BufferLineCycleNext<cr>"

-- LSP: trim what the servers themselves declare. Servers declare which filetypes they
-- handle and that list is what gets enabled *and* installed, so this is the only place to
-- subtract from it. A filetype with no entry here keeps its servers' full declared list.
--
-- Below: the servers that declare `html` but are not wanted in it, so they are neither
-- started nor fetched for it. `:NeovimInfo` on an html buffer lists whatever survives.
--
-- Servers unwanted *everywhere* belong in lua/lsp/config.lua's `skipped_servers` instead.
-- Three that used to be listed here (codebook, oxfmt, gitlab_duo) moved there because they
-- declare 17 to 24 filetypes each, so trimming them one filetype at a time would mean an
-- entry in nearly every table -- and html was only ever the first place they showed up.
lvim.lsp.filetypes = {
    html = {
        exclude = {
            "djls",
            "djlsp",
            "herb_ls",
            "ltex_plus",
            "superhtml",
            "turbo_ls",
            "wc_language_server",
        },
    },
}

-- nvimtree ignore directories
lvim.builtin.nvimtree.setup.filters.custom = {
    "node_modules", "\\.cache", "\\.git", "\\.venv", "\\.idea", "\\.DS_Store"
}

-- monorepo: keep tree root pinned to startup dir, don't follow cwd
lvim.builtin.nvimtree.setup.prefer_startup_root = true
lvim.builtin.nvimtree.setup.sync_root_with_cwd = false
lvim.builtin.nvimtree.setup.update_focused_file.update_root.enable = false
--lvim.log.level = "DEBUG"
