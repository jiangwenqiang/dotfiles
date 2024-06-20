require("bootstrap"):init()

require("config"):load()

require("plugin-loader").load({ require("plugins"), lvim.plugins })

require("core.theme").setup()

local Log = require("core.log")
Log:debug "Starting NeoVim"

local commands = require("core.commands")
commands.load(commands.defaults)
