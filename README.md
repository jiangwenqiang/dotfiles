# Personal Config

## alacritty
...

## neovim
Lean mean Neovim machine, 30-45ms startup time. Works best with [Neovim] = 0.9.5

> I encourage you to fork this repo and create your own experience.
> Learn how to tweak and change Neovim to the way YOU like it.
> This is my cultivation of years of tweaking, use it as a git remote
> and stay in-touch with upstream for reference or cherry-picking.

<details>
  <summary>
    <strong>Table of Contents</strong>
    <small><i>(🔎 Click to expand/collapse)</i></small>
  </summary>

<!-- vim-markdown-toc GFM -->

* [Features](#features)
* [Prerequisites](#prerequisites)
* [Install](#install)
<!-- vim-markdown-toc -->
</details>

### Features

* Fast startup time — plugins are almost entirely lazy-loaded!
* Robust, yet light-weight
* Plugin management with [folke/lazy.nvim]. Use with `:Lazy` 
* Install LSP, DAP, linters, and formatters. Use with `:Mason` 
* LSP configuration with [nvim-lspconfig]
* [telescope.nvim] centric work-flow with lists 
* Unobtrusive, yet informative status & tab lines
* Premium color-schemes

### Prerequisites

* [git](https://git-scm.com/) ≥ 2.19.0 (`brew install git`)
* [Neovim](https://github.com/neovim/neovim/wiki/Installing-Neovim) ≥ v0.9.5
  (`brew install neovim`)

**Optional**, but highly recommended:

* [fzf](https://github.com/junegunn/fzf) (`brew install fzf`)
* [ripgrep](https://github.com/BurntSushi/ripgrep) (`brew install ripgrep`)
* [zoxide](https://github.com/ajeetdsouza/zoxide) (`brew install zoxide`)

### Install

1. Let's clone this repo! Clone to `~/.config/nvim`

    ```bash
    mkdir -p ~/.config
    git clone git@github.com:jiangwenqiang/nvim-allinone.git ~/.config/nvim
    cd ~/.config/nvim
    ```

1. Run `nvim` (will install all plugins the first time).

    It's highly recommended running `:checkhealth` to ensure your system is healthy
    and meet the requirements.

1. Inside Neovim, run `:LazyExtras` and use <kbd>x</kbd> to install extras.

Enjoy! :smile:
