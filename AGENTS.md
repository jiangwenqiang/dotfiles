# AGENTS.md

Orientation for agents working in this repository.

## What this is

A personal macOS configuration repository, deployed by symlinking each component into
place. There is **no installer, no CI, no test suite, and no formatter or linter
configuration** — deployment is a handful of symlinks made by hand, and verification means
running the tool and looking at it.

Which components exist, where each one deploys, and the commands that do it are in
`README.md`. This file does not repeat them.

It is single-machine and deliberately not portable — paths are hardcoded rather than
derived. Do not "fix" one by generalising it unless asked.

## Documentation

Three audiences, three places:

- **`README.md`** (root) — the same project for a human: what the components are, how to
  deploy them, where the docs are.
- **`AGENTS.md`** (this file, root) — the project for an agent: the layout, the conventions,
  and the invariants that are expensive to rediscover. This is the authoritative copy.
- **`CLAUDE.md`** (root) — an import of this file and nothing else. Claude Code reads
  `CLAUDE.md` and **never reads `AGENTS.md`**; the one-line import is the documented bridge,
  so both Claude and the tools that follow the agents.md standard get the same text. Keep
  it content-free — shared instructions belong here, and anything Claude-only goes below
  the import where the other tools will not see it.
- **`docs/<component>/`** — the long-form material, mirroring the top-level directory names
  (`docs/nvim/`, and a directory per component as docs are written). Human-facing; the root
  `README.md` indexes what is there.

Both instruction files must stay at the root: they are found by looking in the working
directory and then every parent, so a copy under `docs/` would never be reached.

A doc is pointed at from the code or section it describes. If you move one, follow the
pointers — `grep -rn '<old path>' .` from the root finds them all.

## Deployment traps

The component list and each one's live path are in `README.md`. What matters when editing:

- **There is no copy or build step** — a file here *is* the live configuration. Most tools
  pick a change up on restart; Alacritty and Neovim reload while running.
- **A fresh clone is not a working setup**, and this file is not a workaround: the symlinks
  are not in the repository.
- **`karabiner/` is the one component not deployed by symlink.** Karabiner-Elements owns the
  live file and rewrites it, so editing the repository copy changes nothing until it is
  re-imported by hand through the app's UI.
- **`fonts/` is copied, not symlinked**, into `~/Library/Fonts`. Editing a TTF here has no
  effect until it is copied again.
- **`zsh/` is reached through `ZDOTDIR`**, set in a real `~/.zshenv` — see the zsh section.

### Runtime files land inside the repository

Because `zsh/` is `~/.config/zsh` and Neovim's config dir is `nvim/`, programs write their
state into tracked directories: `.zcompdump*`, `.zsh_history`, `.zsh_sessions/` in `zsh/`,
and `lazy-lock.json` in `nvim/`. All are gitignored. Do not commit them, and do not delete
`.zsh_history` to tidy up.

## Component traps

Not an inventory — `README.md` has that. Only the things that are not obvious from reading
a component's files.

### alacritty

- `live_config_reload = true`, so a malformed TOML surfaces in the running window and the
  previous config stays in effect. A reload is not a safe way to test a change.
- `themes/gruvbox-material-alacritty.yml` predates the TOML switch and is imported by
  nothing — the `themes/` directory is not all live.

### fonts

`fonts/lilex/` is what Alacritty uses; `fonts/jetbrains/` is tracked but referenced by
nothing here. There is no install script.

### karabiner

What the repository tracks is `karabiner/karabiner_modifications.json`, the rules imported
by hand through Karabiner's UI (Complex modifications → Add) — *not* the live
`~/.config/karabiner/karabiner.json`, which the app owns and rewrites. The rule currently
defined: tapping `left_control` toggles the input source between English and Simplified
Chinese.

### nvim

The bulk of the repository. `docs/nvim/lsp.md` documents the language-server design in
detail — read it before touching anything under `nvim/lua/lsp/`.

| Path | What it is |
| --- | --- |
| `nvim/init.lua` | Startup: bootstrap → `require("config"):init()` → user config → plugins. |
| `nvim/config.lua` | **The user config.** `dofile`d, not `require`d, after `lvim` exists. |
| `nvim/lua/config/` | `require("config")` — the framework loader that builds the `lvim` global. |
| `nvim/lua/lsp/` | Language servers. See `docs/nvim/lsp.md`. |
| `nvim/lua/core/` | Builtins: theme, statusline, telescope, autocmds, `:NeovimInfo`. |
| `nvim/lua/plugins.lua` | lazy.nvim plugin specs. |
| `nvim/snapshots/default.json` | The tracked plugin pin. |
| `nvim/bin/xkbswitch` | Compiled universal Mach-O binary, tracked in git, built from `nvim/kits/xkbswitch` with `make`. Switches the macOS input source per buffer via `nvim/lua/core/xkbswitch.lua` — see `docs/nvim/input-source.md`. |

`nvim/config.lua` and `nvim/lua/config/init.lua` are different files. So is
`nvim/lua/lsp/config.lua`, whose return value is **deepcopied** into `lvim.lsp`; the user
config mutates `lvim.lsp.*` at runtime instead of editing it. (There is also
`nvim/lua/lsp/jdtls/config.lua`, jdtls-only helpers.)

`lvim.reload_config_on_save` is on, so saving `nvim/config.lua` while Neovim runs reloads
the configuration in place.

Invariants — each of these was learned by breaking it, and the failure shows up far from
the cause:

- **A server's declared `filetypes` is the source of truth; configuration only subtracts.**
  Never add a filetype to a server by hand.
- **Install set = enable set**, both computed from `filetypes.effective(s)`. Do not
  introduce a second list that can drift.
- **Only mason-shipped servers take part.** Do not restore a "no mason package, so assume
  it is installed" fallback — it enables ~112 servers nobody asked for, and the ones whose
  command resolves (`npx`, `node`, `python`) really are spawned.
- **Servers unwanted everywhere go in `skipped_servers`, not `filetypes[ft].exclude`.**
  Per-filetype exclusion does not scale to a server declaring 20+ filetypes.
- Comments under `nvim/lua/lsp/` record non-obvious reasons deliberately. Keep them true
  when changing the code beneath them.

Smaller things that cost time to rediscover:

- `:NeovimInfo` is the LSP status popup. `:LspInfo` no longer exists — nvim-lspconfig 2.x
  removed it, and the only surviving reference in this config sets a window border.
- Global helpers (`get_config_dir`, `get_runtime_dir`, `join_paths`, `reload`,
  `require_clean`) are defined in `nvim/lua/bootstrap.lua` and never imported.
- A package can be installed on disk and still not run: `skipped_servers` stops a server
  being *used*, it does not remove it. `:MasonUninstall <package>` does.
- `nvim/lua/lsp/null-ls/` (formatters and linters) and `nvim/lua/core/info.lua` (rendering
  them) are a separate system from the language-server machinery.

### tmux

The status line shells out (`tmux-mem-cpu-load`, `uptime`). A binary that is missing leaves
a blank segment rather than an error, so a blank segment is the symptom to look for — not a
crash.

### zed

Zed writes into `zed/prompts/`, `zed/conversations/` and `zed/themes/`, all gitignored —
local state, not configuration. Do not commit them, and do not treat them as lost config
when they are absent.

### zsh

Not deployed by symlinking dotfiles. `~/.zshenv` is a real file whose only job is:

```sh
export ZDOTDIR="$HOME/.config/zsh"
```

`~/.config/zsh` is a symlink to `zsh/`, so zsh then reads `zsh/.zshenv`, `zsh/.zprofile` and
`zsh/.zshrc` from here. `zsh/.zshrc` sources, in order: `oh-my.zsh` (oh-my-zsh, theme
disabled), `base.zsh` (EDITOR, locale, PATH), `functions.zsh`, `completions.zsh`,
`plugins.zsh` (edit-command-line, zoxide, starship), `proxy.zsh`, `dev.zsh` (SDKMAN, NVM,
pnpm, newest uv-managed CPython), and finally `ai.zsh` if present (gitignored).

There is also a `~/.zshrc` on this machine, owned by root, containing one line. `ZDOTDIR`
shadows it, so it is **never read** — do not put anything there expecting it to run.

`dev.zsh`'s SDKMAN block carries a "THIS MUST BE AT THE END OF THE FILE" comment but sits at
the top of the file, and `dev.zsh` is not the last thing `.zshrc` sources. If SDKMAN
behaves oddly, that discrepancy is the place to look.

## Conventions

- Comment language varies by component and is worth matching: `zsh/` is commented in
  Chinese, `nvim/` in English, `alacritty/` uses ASCII-art section banners, `tmux/` is
  plain English.
- Indentation is not uniform either: most of `nvim/lua/` uses 2 spaces, but
  `nvim/lua/lsp/providers/jdtls.lua` uses 4. Match the file you are in.
- Commit messages are English and imperative. Some use Conventional Commits prefixes
  (`feat(nvim):`, `refactor:`, `chore:`); many are plain ("Update dev.zsh").
- Gitignored, local-only: `.DS_Store`, `lazy-lock.json`, `.zcompdump*`, `.zsh_history`,
  `zsh/ai.zsh`, `.claude-code.zsh`, `zed/{prompts,conversations,themes}/`.

## Verifying a change

There is no harness to run. Do not report a change as verified on the strength of a command
that exited 0 — there is no such command, and the Makefile inside `nvim/` is inherited from
upstream LunarVim: its targets reference a `utils/` directory that is not here, `style-lua`
wants a `.stylua.toml` that does not exist, and neither `stylua` nor `luacheck` is
installed.

- **nvim** — run it headless and assert on real state. Pass a real file: the LSP setup path
  is lazy (it hangs off `User LazyDone` and a self-deleting `BufRead` autocmd), so a probe
  that opens no file reads as "nothing is enabled". `docs/nvim/lsp.md` has a probe template.
- **zsh** — `zsh -n zsh/<file>` parses without executing, and is clean for every file here.
  There is no equivalent one-liner for the whole startup: `zsh -i -c exit` reports
  `can't change option: zle` and exits 1, because `plugins.zsh` calls `zle -N` and a shell
  without a tty has no zle. That is an artifact of the invocation, not a fault in the
  config — open a terminal window instead, and read what it prints.
- **tmux** — `tmux source-file ~/.config/tmux/tmux.conf` against a running server. It is
  not a dry run; it applies to that server immediately.
- **alacritty** — reloads live; watch the window rather than a command.
- **zed, karabiner** — no CLI check. Restart the app, or re-import for Karabiner.
