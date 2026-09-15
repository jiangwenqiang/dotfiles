-- JDTLS LSP provider configuration
-- Returns opts for nvim-lspconfig to launch the Java Language Server

local config = require("lsp.jdtls.config")
local lombok = require("lsp.jdtls.lombok")

---Session-scoped settings. These do not depend on the project, so resolving them once
---is correct. Everything project-dependent (`-data`, `maven.userSettings`) is computed
---per client instead -- see `cmd` and `before_init` below.
---
---The split matters because this module is `require`d exactly once, from
---`lsp/manager.lua::resolve_config()` at startup. A project root captured here would
---freeze to whatever buffer happened to be open at startup, and every later Java
---project in the same session would inherit its workspace directory.
local session = (function()
    local runtimes   = config.get_sdkman_runtimes()
    local jdtls_root = vim.fn.stdpath("data") .. "/mason/packages/jdtls"

    local argv = {
        config.get_java_executable(runtimes),
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dosgi.checkConfiguration=true",
        "-Dosgi.sharedConfiguration.area=" .. vim.fs.joinpath(jdtls_root, config.get_config_area_name()),
        "-Dosgi.sharedConfiguration.area.readOnly=true",
        "-Dosgi.configuration.cascaded=true",
        "-Djava.import.generatesMetadataFilesAtProjectRoot=false",
        "-Dlog.protocol=true",
        "-Dlog.level=ALL",
        "-Xms1g",
        "--add-modules=ALL-SYSTEM",
        "--add-opens", "java.base/java.util=ALL-UNNAMED",
        "--add-opens", "java.base/java.lang=ALL-UNNAMED",
    }

    local lombok_jar = lombok.ensure({ jdtls_root = jdtls_root })
    if lombok_jar then
        table.insert(argv, "-javaagent:" .. lombok_jar)
    end

    return {
        argv       = argv,
        runtimes   = runtimes,
        launcher   = vim.fn.glob(jdtls_root .. "/plugins/org.eclipse.equinox.launcher_*.jar"),
        config_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "jdtls", "config"),
    }
end)()

---The project-dependent tail of the command line.
---@param project_root string|nil Root resolved per buffer by `vim.lsp.start`
---@return string[] args
local function project_args(project_root)
    return {
        "-jar", session.launcher,
        "-configuration", session.config_dir,
        "-data", config.get_workspace_dir(project_root),
    }
end

---Resolve `.mvn/maven.config` for this client's project.
---
---`settings` cannot be a function, so this runs as a hook. It has to be `before_init`
---rather than `on_init`: Neovim sends `workspace/didChangeConfiguration` before `on_init`
---runs, so a value set there would be too late for the server's first read.
---@param _ lsp.InitializeParams
---@param client_config vim.lsp.ClientConfig
local function apply_maven_settings(_, client_config)
    local project_root = client_config.root_dir

    -- `.mvn/maven.config` is a Maven thing, so only look for it in a Maven project.
    -- A Gradle, Ant or plain git root resolves to a project_root too, and jdtls is
    -- perfectly happy without maven.userSettings there.
    local maven_settings = nil
    if config.is_maven_project(project_root) then
        maven_settings = config.get_maven_settings(project_root)
        if not maven_settings then
            vim.notify("[jdtls] No Maven settings found in .mvn/maven.config", vim.log.levels.WARN)
        end
    end

    -- Mutate in place: `client.settings` aliases this table, so assigning the field
    -- wholesale would leave the client pointed at the old one.
    client_config.settings.java.configuration.maven.userSettings = maven_settings
end

return {
    ---A function `cmd` is what makes `-data` per-project. `vim.lsp.start` resolves
    ---`root_dir` per buffer on a copy of the config and hands that same copy to this
    ---function, so `client_config.root_dir` is *this* client's project even though the
    ---stored config is static.
    cmd = function(dispatchers, client_config)
        local argv = vim.list_extend(vim.deepcopy(session.argv), project_args(client_config.root_dir))
        return vim.lsp.rpc.start(argv, dispatchers, {
            cwd      = client_config.cmd_cwd,
            env      = client_config.cmd_env,
            detached = client_config.detached,
        })
    end,

    root_markers = config.get_root_markers(),

    filetypes = { "java" },

    before_init = apply_maven_settings,

    on_attach = function(client, bufnr)
        require("lsp").common_on_attach(client, bufnr)
        require("lsp.jdtls.decompile").setup(client, bufnr)
    end,

    settings = {
        java = {
            signatureHelp = { enabled = true },
            completion = {
                favoriteStaticMembers = {
                    "org.junit.Assert.*",
                    "org.junit.Assume.*",
                    "org.junit.jupiter.api.Assertions.*",
                    "org.junit.jupiter.api.Assumptions.*",
                    "org.junit.jupiter.api.DynamicContainer.*",
                    "org.junit.jupiter.api.DynamicTest.*",
                    "org.mockito.Mockito.*",
                    "org.mockito.ArgumentMatchers.*",
                },
                filteredTypes = {
                    "com.sun.*",
                    "io.micrometer.shaded.*",
                    "java.lang.*",
                    "java.util.*",
                    "sun.*",
                },
                importOrder = { "java", "javax", "com", "org" },
            },
            sources = {
                organizeImports = {
                    starThreshold = 9999,
                    staticStarThreshold = 9999,
                },
            },
            codeGeneration = {
                toString = {
                    template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
                },
                useBlocks = true,
            },
            configuration = {
                runtimes = session.runtimes,
                -- Filled in per project by `apply_maven_settings`.
                maven = {},
            },
            format = {
                enabled = true,
            },
        },
    },

    init_options = {
        bundles = {},
        extendedClientCapabilities = {
            actionableRuntimeNotificationSupport = true,
            advancedExtractRefactoringSupport = true,
            advancedGenerateAccessorsSupport = true,
            advancedIntroduceParameterRefactoringSupport = true,
            advancedOrganizeImportsSupport = true,
            advancedUpgradeGradleSupport = true,
            classFileContentsSupport = true,
            clientDocumentSymbolProvider = false,
            clientHoverProvider = false,
            executeClientCommandSupport = true,
            extractInterfaceSupport = true,
            generateConstructorsPromptSupport = true,
            generateDelegateMethodsPromptSupport = true,
            generateToStringPromptSupport = true,
            gradleChecksumWrapperPromptSupport = true,
            hashCodeEqualsPromptSupport = true,
            inferSelectionSupport = {
                'extractConstant',
                'extractField',
                'extractInterface',
                'extractMethod',
                'extractVariableAllOccurrence',
                'extractVariable',
            },
            moveRefactoringSupport = true,
            onCompletionItemSelectedCommand = 'editor.action.triggerParameterHints',
            overrideMethodsPromptSupport = true,
        },
    },
}
