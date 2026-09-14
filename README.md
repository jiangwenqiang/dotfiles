# dotfiles

My macOS setup, tracked in git: terminal, shell, editor, multiplexer, prompt, keyboard and
fonts. Everything is deployed by symlink, so a file in this repository *is* the live
configuration — there is no build step and no copy.

It is single-machine and deliberately not portable. `/Users/hermes` is hardcoded in
`zed/settings.json` (Java runtimes), `zsh/dev.zsh` (`PNPM_HOME`) and a comment in
`alacritty/alacritty.toml`.

## What's in here

| Directory | What it configures | Deployed to |
| --- | --- | --- |
| [`alacritty/`](alacritty/) | Terminal — Catppuccin Mocha, Lilex Nerd Font Mono, live reload | `~/.config/alacritty` |
| [`nvim/`](nvim/) | Editor — LunarVim-derived, lazy.nvim, LSP/formatting | `~/.config/nvim` |
| `nvim/.ideavimrc` | IdeaVim keybindings | `~/.ideavimrc` |
| [`fonts/`](fonts/) | Lilex and JetBrains Nerd Fonts | *copied* into `~/Library/Fonts` |
| [`karabiner/`](karabiner/) | Left-Control toggles EN/中文 input source | *imported by hand* |
| [`starship/`](starship/) | Prompt — initialised from `zsh/plugins.zsh` | `~/.config/starship.toml` |
| [`tmux/`](tmux/) | Prefix `C-a`, status line | `~/.config/tmux` |
| [`zed/`](zed/) | Editor — vim mode, Java runtime list | `~/.config/zed` |
| [`zsh/`](zsh/) | Shell — oh-my-zsh, zoxide, starship, SDKMAN, NVM, uv | `~/.config/zsh` |

## Deploying

There is no installer — a fresh clone is not a working setup. The symlinks are made by
hand. Most are directory-level:

```sh
ln -s ~/path/to/dotfiles/alacritty  ~/.config/alacritty
ln -s ~/path/to/dotfiles/nvim       ~/.config/nvim
ln -s ~/path/to/dotfiles/tmux       ~/.config/tmux
ln -s ~/path/to/dotfiles/zed        ~/.config/zed
ln -s ~/path/to/dotfiles/zsh        ~/.config/zsh
ln -s ~/path/to/dotfiles/starship/starship.toml ~/.config/starship.toml
ln -s ~/path/to/dotfiles/nvim/.ideavimrc        ~/.ideavimrc
```

Two components are not symlinked at all:

- **fonts** — copy the TTFs from `fonts/lilex/` into `~/Library/Fonts`.
- **karabiner** — Karabiner-Elements owns `~/.config/karabiner/karabiner.json` and rewrites
  it, so the repository tracks only `karabiner_modifications.json`. Import it through the
  UI (Complex modifications → Add); editing the file alone changes nothing.

zsh needs one more piece, because its config dir is not read by default:

```sh
echo 'export ZDOTDIR="$HOME/.config/zsh"' > ~/.zshenv
```

## Documentation

Longer write-ups live in [`docs/`](docs/), one directory per component:

- [`docs/nvim/lsp.md`](docs/nvim/lsp.md) — how language servers are chosen, enabled and
  installed.
- [`docs/nvim/input-source.md`](docs/nvim/input-source.md) — the per-buffer macOS input
  source, and the `bin/xkbswitch` binary behind it.

Components without an entry are small enough to read directly. New docs go in
`docs/<component>/`, and get added to this list.

`AGENTS.md` covers the same repository for AI agents: the layout of the larger components,
the conventions, and the traps that are expensive to rediscover — the things that are not
obvious from reading a component's files. **The tables above are the canonical list** of what
exists and where it deploys; `AGENTS.md` points here rather than repeating them. It is worth
a read even if you are not an agent.
