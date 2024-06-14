-- Prepare env and setup the default configuration and variables
require("bootstrap"):init()
-- Override the configuration with a user provided one
require("config"):load()
-- Load plugins
require("plugin-loader").load({ require("plugins"), lvim.plugins })
-- Load themes
require("core.theme").setup()
-- Load the builtin commands
require("core.commands").load()
