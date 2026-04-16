-- JDTLS LSP provider configuration
-- Returns opts for nvim-lspconfig to launch the Java Language Server

local config = require("lsp.jdtls.config")
local lombok = require("lsp.jdtls.lombok")

---@return table opts LSP configuration options
local function build_config()
    local project_root   = config.find_project_root(vim.fn.expand("%:p"))
    local maven_settings = config.get_maven_settings(project_root)
    if not maven_settings and project_root then
        vim.notify("[jdtls] No Maven settings found in .mvn/maven.config", vim.log.levels.WARN)
    end

    local runtimes           = config.get_sdkman_runtimes()
    local java_executable    = config.get_java_executable(runtimes)
    local mason_jdtls_path   = vim.fn.stdpath("data") .. "/mason/packages/jdtls"
    local jdtls_cache_root   = vim.fn.stdpath("cache") .. "/jdtls"
    local shared_config_area = vim.fs.joinpath(mason_jdtls_path, config.get_config_area_name())
    local config_dir         = vim.fs.joinpath(jdtls_cache_root, "config")
    local workspace_dir      = config.get_workspace_dir(project_root);
    local lombok_jar         = lombok.ensure({ jdtls_root = mason_jdtls_path, })

    local cmd                = {
        java_executable,
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dosgi.checkConfiguration=true",
        "-Dosgi.sharedConfiguration.area=" .. shared_config_area,
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

    if lombok_jar then
        table.insert(cmd, "-javaagent:" .. lombok_jar)
    end

    vim.list_extend(cmd, {
        "-jar",
        vim.fn.glob(mason_jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar"),
        "-configuration",
        config_dir,
        "-data",
        workspace_dir,
    })

    return {
        cmd = cmd,

        root_markers = config.get_root_markers(),

        filetypes = { "java" },

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
                    runtimes = runtimes,
                    maven = {
                        userSettings = maven_settings
                    }
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
end

return build_config()
