# Language server handling

How this config decides which language servers exist, which ones run, and when they get
installed. Paths are relative to the repository root.

## The one rule

A server declares the filetypes it handles. Neovim matches a buffer's filetype against that
list verbatim, so **the server's own declaration is the source of truth** and the
configuration only ever subtracts from it. There is no way to add.

```
declared(s)  = the `filetypes` in nvim-lspconfig's lsp/<s>.lua, read off the runtimepath

effective(s) = declared(s)
               − everything,        when s is out of scope   (mason ships no package)
               − everything,        when s ∈ skipped_servers
               − every filetype    in skipped_filetypes
               − filetypes[ft].exclude, one filetype at a time
```

`effective(s)` is the single source of truth. It is the set of filetypes a server attaches
to **and** — because the install queue is built by walking it — the set it will be installed
for. **Install set = enable set.** There is no second list to keep in sync.

`lvim.lsp.filetypes[ft] = false` drops every server for that filetype.

## Where the pieces live

| Path | Responsibility |
| --- | --- |
| `nvim/lua/lsp/config.lua` | User-facing defaults: `skipped_servers`, `skipped_filetypes`, `filetypes`, installer setup, buffer mappings/options. Consumed as `lvim.lsp`. |
| `nvim/lua/lsp/filetypes.lua` | The mapping itself: `declared`, `effective`, `servers_for(ft)`, `validate()`, `reset()`, and the `in_scope` hook. |
| `nvim/lua/lsp/manager.lua` | Enables and installs. `is_managed`, `is_installed`, `setup()`. The only module that knows about mason. |
| `nvim/lua/lsp/init.lua` | Entry point. `common_capabilities` / `common_on_attach` / `common_on_init` / `common_on_exit`, and `setup()` which calls the manager. |
| `nvim/lua/lsp/providers/*.lua` | Per-server overrides, merged over the defaults by `manager.resolve_config()`. `jdtls`, `jsonls`, `lua_ls`, `tailwindcss`, `vuels`, `yamlls`. |
| `nvim/lua/lsp/jdtls/*` | jdtls-only helpers: `config.lua` (paths, markers, workspace dir), `lombok.lua`, `decompile.lua`. |
| `nvim/lua/lsp/null-ls/*` | Formatters, linters and code actions. A separate system from the above. |
| `nvim/lua/core/info.lua` | The `:NeovimInfo` popup, including the automatic-LSP section. |
| `nvim/config.lua` | **The user config** (`dofile`d, not `require`d). Where `lvim.lsp.filetypes[ft].exclude` is written. |

## Enable and install

`lsp.setup()` runs once per session — `manager.setup()` walks every server on the
runtimepath and, for each one with a non-empty `effective`:

- **already installed** → `vim.lsp.config(name, config)` then `vim.lsp.enable(name)`, and
  Neovim attaches it to matching buffers by itself;
- **not installed** → recorded under each of its effective filetypes in a `pending` table.

A `FileType` autocmd (augroup `LvimLspAutomaticInstall`) then installs `pending[ft]` the
first time a file of that type is opened, and activates the server once the install
finishes. That is what makes **trimming a server out of a filetype mean it is never
installed for it either** — the queue is built from `effective`, so a trimmed server is not
in it.

`activate()` replaces `config.filetypes` when the list was trimmed, because
`vim.lsp.config()` replaces array values rather than merging them.

### Two trigger points

`lsp.setup()` is wired up in two places, whichever fires first wins (`manager.setup()` is
idempotent):

- `nvim/lua/plugin-loader.lua` — `User LazyDone`, once lazy.nvim has finished;
- `nvim/lua/core/autocmds.lua` — the `_file_opened` augroup on `BufRead` / `BufWinEnter` /
  `BufNewFile`, which deletes itself after firing.

## The scope boundary

Only servers **mason ships a package for** take part at all
(`mason-lspconfig.get_mappings().lspconfig_to_package`). This is the boundary the config
has always drawn — mason-lspconfig's own `automatic_enable` iterates that same mapping and
nothing else.

It has to be explicit because there are 392 servers on the runtimepath and only 178 have a
package. Treat "no package" as "nothing to manage" and the other 112 get attached to every
buffer of any filetype they declare. Most of them die on a missing executable, but a few do
not — `gitlab_duo` runs `npx`, `turtle_ls` runs `node`, `tvm_ffi_navigator` runs `python` —
and those really do get spawned on every Java or HTML buffer you open.

The boundary lives in `nvim/lua/lsp/filetypes.lua` (`M.in_scope`, injected by the manager) rather than
inside `manager.setup()`, so that `effective()` and `servers_for()` tell the truth to every
consumer. Filtering only in the manager leaves `:NeovimInfo` listing servers that will
never run — and, since `is_installed()` returns false for them, listing them under
*Awaiting install*, which is a lie.

Out-of-scope servers are still recorded in `declared`, because that reading of what the
servers say stays faithful and `validate()` needs it to tell a typo apart from a rule that
bit.

## How to trim

Pick the lever by asking **where** the server is unwanted:

- **Everywhere** → `skipped_servers` in `nvim/lua/lsp/config.lua`. One line, and the server
  neither runs nor gets installed for any filetype.
- **In one filetype only** → `lvim.lsp.filetypes[ft].exclude` in `nvim/config.lua`. For
  servers you want elsewhere but not here.

Servers that declare many filetypes belong in `skipped_servers` even when the symptom shows
up in one place. `codebook` declares 21 filetypes, `gitlab_duo` 24, `oxfmt` 17 — trimming
those one filetype at a time means an entry in nearly every table, and the next filetype
you open brings the same server back.

`:NeovimInfo` on a buffer shows what survived: the running clients, then
`Enabled:` and `Awaiting install:` for that filetype.

## jdtls: the project-dependent parts

`nvim/lua/lsp/providers/jdtls.lua` is `require`d exactly once, at startup, via
`manager.resolve_config()`. Anything project-dependent captured at require time would
freeze to whatever buffer happened to be open then — so the provider is split in two:

- **Session-scoped** (the returned table): the JVM argv, SDKMAN runtimes, the lombok agent,
  the equinox launcher jar. None of it depends on the project, so resolving it once is
  correct.
- **Per client** (the `cmd` function and `before_init`): `-data <workspace dir>` and
  `maven.userSettings`. `vim.lsp.start()` resolves `root_dir` per buffer on a deep copy of
  the config and hands that same copy to `cmd`, so `client_config.root_dir` is *this*
  client's project even though the stored config is static. `config.get_workspace_dir()`
  hashes the root, so each project gets its own Eclipse workspace.

`before_init` rather than `on_init`: Neovim sends `workspace/didChangeConfiguration` before
`on_init` runs, so a setting written there would be too late for the server's first read.
It mutates `client_config.settings.java.configuration.maven.userSettings` **in place** —
`client.settings` aliases that table, and reassigning the field wholesale would leave the
client pointing at the old one.

Note `_root_markers` is an `opts` field, not a config field — `vim.lsp.start` only resolves
a root when it is passed as `{ _root_markers = ... }`.

## Pitfalls this design has already hit

- **`automatic_installation` is a dead key** in mason-lspconfig 2.x; nothing ever read it,
  so nothing was ever installed ahead of time. `automatic_enable` defaults to **true**, and
  `ensure_installed` / `automatic_enable` are the keys that exist.
- **New mason packages drift in.** The queue is built from what servers declare, so a
  package added upstream that declares a filetype you open gets installed and enabled
  without anyone asking for it. That is how `codebook` arrived: a spell checker, the same
  category as the already-skipped `harper_ls` and `ltex`, which happens to declare `java`.
  The reactive answer is another `skipped_servers` line; the structural answer would be to
  invert the default so only listed servers take part.
- **Per-filetype exclusion does not scale** to servers that declare 20+ filetypes.
- **`vim.fs.root` special-cases bufnrs**: for a buffer whose `buftype` is not `''` it
  resolves against `uv.cwd()` instead of the buffer name. `nvim_create_buf(false, true)`
  gives `buftype=nofile`, so probes written that way silently measure the cwd.

## Verifying a change

The setup path is lazy, so a probe that opens no real file never runs any of it. Pass a
real file as an argument and defer:

```bash
nvim --headless -u "$HOME/.config/dotfiles/nvim/init.lua" lua/plugins.lua \
     -c "luafile /tmp/probe.lua"
```

```lua
-- /tmp/probe.lua
local function out(s) io.stdout:write(s .. "|END\n") end
vim.defer_fn(function()
  local ft = require "lsp.filetypes"
  for _, t in ipairs { "java", "html", "lua", "python" } do
    out(("ATTACH[%s]=%s"):format(t, table.concat(ft.servers_for(t), " ")))
  end
  local on, off = {}, {}
  for _, n in ipairs(ft.servers()) do
    if #ft.effective(n) > 0 then
      table.insert(require("lsp.manager").is_installed(n) and on or off, n)
    end
  end
  out("ENABLED=" .. #on .. " AWAITING_INSTALL=" .. #off)
  out "DONE"
  vim.cmd "qa!"
end, 8000)
```

`ATTACH[java]` should be exactly `jdtls`; anything else in there is a server that will be
spawned the next time you open a Java file.
