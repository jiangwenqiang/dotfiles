# Input source

Remembering the macOS input source per buffer, so that a buffer you type Chinese in is
still on Chinese when you come back to it — and so that leaving insert mode always gives
you back English for normal-mode keys.

Without this, whichever layout you last used while typing follows you into normal mode: a
Chinese IME swallows `:` or `dd` and inserts full-width punctuation instead.

## Behaviour

| Event | What happens |
| --- | --- |
| `InsertLeave` | Reads the current layout, stores it against the buffer, then switches to English. |
| `InsertEnter` | Restores the layout stored for that buffer, if there is one. |

The memory is per buffer, so two splits can sit on different layouts at the same time. A
buffer that has never been left in insert mode has nothing stored, and `InsertEnter` leaves
the current layout alone.

## Configuration

`nvim/lua/core/xkbswitch.lua` is a builtin: `nvim/lua/core/builtins/init.lua` calls its
`M.config(opts)`. The one option is the layout to fall back to:

```lua
M.config({ nlang = "com.apple.keylayout.ABC" })  -- the default
```

`com.apple.keylayout.ABC` is what macOS calls the plain English layout. Run
`xkbswitch` with no arguments to print the identifier of the layout you are on, if you
need the name of another one.

## The binary

`nvim/bin/xkbswitch` is a **universal Mach-O binary tracked in git**, not built on
install — it is what actually reads and sets the layout, since Neovim has no API for this.
Its source lives in `nvim/kits/xkbswitch/` (`xkbswitch.m`, one file).

To rebuild after editing the source, from `nvim/kits/xkbswitch/`:

```bash
make
mv xkbswitch ../../bin
rm xkbswitch-arm xkbswitch-x86
```

`make` builds both architectures and `lipo`s them into one binary; the two per-arch
binaries in between are not needed afterwards.

The command line is deliberately tiny:

```bash
xkbswitch                              # print the current layout
xkbswitch com.apple.keylayout.ABC      # switch to it
```

Neovim calls it through `vim.fn.jobstart`, so a switch never blocks the editor. If setting
a layout fails — the identifier is wrong, or the layout is not installed — the stderr
handler forgets the layout stored for that buffer rather than retrying it on every
`InsertEnter`.
