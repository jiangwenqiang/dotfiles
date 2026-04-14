 -----------------------------------------------------------------------------
-- JDTLS (Java Language Server) Configuration
--
-- Features:
--   - Dynamically discovers Java runtimes from SDKMAN
--   - Adapts Maven settings from .mvn/maven.config (compatibility layer)
--   - Uses highest Java version (>= 17) for JDTLS startup
--   - Supports debugging and testing via bundled extensions
--
-- Requirements:
--   - Java 17 or higher (auto-detected from SDKMAN)
--   - jdtls installed via Mason
-- -----------------------------------------------------------------------------

local util = require("lspconfig.util")

-- =============================================================================
-- Maven Configuration
-- =============================================================================

--- Read .mvn/maven.config to extract custom settings path
--- Provides compatibility layer between Maven CLI and JDTLS
--- @param project_root string Project root directory
--- @return string|nil Absolute path to settings.xml, or nil if not found
local function get_maven_settings(project_root)
    local config_file = project_root .. "/.mvn/maven.config"

    if vim.fn.filereadable(config_file) == 0 then
        return nil
    end

    local content = vim.fn.readfile(config_file)
    local settings_path = nil

    for _, line in ipairs(content) do
        -- Skip comments and empty lines
        if not line:match("^%s*#") and line:match("%S") then
            -- Match -s path or --settings path
            local path = line:match("^-[sS]%s+(.+)$")
                or line:match("^--settings%s+(.+)$")

            if path then
                path = path:match("^%s*(.-)%s*$")

                -- Handle relative/absolute paths
                if not vim.startswith(path, "/") and not vim.startswith(path, "~") then
                    path = project_root .. "/" .. path
                else
                    path = vim.fn.expand(path)
                end

                settings_path = path
                break
            end
        end
    end

    return settings_path
end

-- =============================================================================
-- Java Runtime Discovery
-- =============================================================================

--- Discover all Java runtimes from SDKMAN
--- Returns sorted list (highest version first) for JDTLS configuration
--- @return table Array of runtime configurations with name, path, and default flag
local function get_sdkman_runtimes()
    local java_path = vim.fn.expand("~/.sdkman/candidates/java")
    local runtimes = {}

    if vim.fn.isdirectory(java_path) == 0 then
        return runtimes
    end

    local entries = vim.fn.readdir(java_path)

    -- Sort by version number (not string) to get latest version first
    table.sort(entries, function(a, b)
        local ver_a = tonumber(a:match("^(%d+)") or 0)
        local ver_b = tonumber(b:match("^(%d+)") or 0)
        return ver_a > ver_b
    end)

    for _, entry in pairs(entries) do
        local full_path = java_path .. "/" .. entry

        -- Skip symbolic links like 'current'
        if vim.fn.isdirectory(full_path) == 1 and entry ~= "current" then
            local java_major = entry:match("^(%d+)%.")
            if java_major then
                table.insert(runtimes, {
                    name = "JavaSE-" .. java_major,
                    path = vim.fn.expand("~/.sdkman/candidates/java/" .. entry),
                    default = (#runtimes == 0),  -- First (highest) version is default
                })
            end
        end
    end

    return runtimes
end

--- Get Java executable for JDTLS startup
--- Requires Java 17+ (JDTLS minimum requirement)
--- @return string|nil Path to java executable, or nil if not found
local function get_jdtls_java_executable()
    local runtimes = get_sdkman_runtimes()

    if #runtimes > 0 then
        local highest = runtimes[1]
        local major_version = tonumber(highest.name:match("JavaSE-(%d+)"))

        if major_version and major_version >= 17 then
            return highest.path .. "/bin/java"
        else
            error("JDTLS requires Java 17 or higher, but found: " .. highest.name ..
                  "\nPlease install Java 17+ using: sdk install java 21.0.10-tem")
        end
    end

    return nil
end

-- =============================================================================
-- JDTLS Bundles (Debug & Test Support)
-- =============================================================================

--- JDTLS extension bundles for debugging and testing
local bundles = {}

local jdtls_extensions = vim.fn.stdpath("data") .. "/mason/packages/jdtls/extension/server/"

-- Add debug adapter bundle (for DAP support)
local debug_adapter_path = vim.fn.glob(jdtls_extensions)
if debug_adapter_path ~= "" then
    local bundle = vim.fn.glob(debug_adapter_path .. "com.microsoft.java.debug.plugin_*.jar")
    if bundle ~= "" then
        table.insert(bundles, bundle)
    end
end

-- Add test bundle (for JUnit support)
local test_adapter_path = vim.fn.glob(jdtls_extensions)
if test_adapter_path ~= "" then
    local bundle = vim.fn.glob(test_adapter_path .. "junit-jars/*.jar", true)
    if bundle ~= "" then
        vim.list_extend(bundles, vim.split(bundle, "\n"))
    end
end

-- =============================================================================
-- LSP Configuration
-- =============================================================================

local jdtls_java = get_jdtls_java_executable()
local java_executable = jdtls_java or "java"
local mason_jdtls_path = vim.fn.stdpath("data") .. "/mason/packages/jdtls"

local opts = {
    -- -------------------------------------------------------------------------
    -- JDTLS Startup Command
    -- -------------------------------------------------------------------------
    cmd = {
        java_executable,
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dosgi.checkConfiguration=true",
        "-Dosgi.sharedConfiguration.area=" .. mason_jdtls_path .. "/config",
        "-Dosgi.sharedConfiguration.area.readOnly=true",
        "-Dosgi.configuration.cascaded=true",
        "-Djava.import.generatesMetadataFilesAtProjectRoot=false",
        "-Dlog.protocol=true",
        "-Dlog.level=ALL",
        "-Xms1g",
        "--add-modules=ALL-SYSTEM",
        "--add-opens", "java.base/java.util=ALL-UNNAMED",
        "--add-opens", "java.base/java.lang=ALL-UNNAMED",
        "-jar",
        vim.fn.glob(mason_jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar"),
        "-configuration",
        mason_jdtls_path .. "/config",
        "-data",
        vim.fn.stdpath("cache") .. "/jdtls-workspace",
    },

    -- -------------------------------------------------------------------------
    -- Project Root Detection
    -- -------------------------------------------------------------------------
    root_dir = function(fname)
        local root = util.root_pattern("build.gradle", "build.gradle.kts", "pom.xml", "settings.gradle")(fname)
        if root then
            return root
        end
        return util.find_git_ancestor(fname)
    end,

    -- -------------------------------------------------------------------------
    -- Dynamic Configuration Hook
    -- -------------------------------------------------------------------------
    on_new_config = function(config, root_dir)
        -- Resolve Maven settings for this project
        local maven_user_settings = nil

        -- Priority 1: .mvn/maven.config (adaptation layer)
        local settings_from_config = get_maven_settings(root_dir)
        if settings_from_config then
            maven_user_settings = settings_from_config
        else
            -- Priority 2: .mvn/settings.xml (Maven standard)
            local mvn_settings = root_dir .. "/.mvn/settings.xml"
            if vim.fn.filereadable(mvn_settings) == 1 then
                maven_user_settings = mvn_settings
            end
        end

        -- Apply Maven settings to JDTLS configuration
        if maven_user_settings then
            config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
                java = {
                    configuration = {
                        maven = {
                            userSettings = maven_user_settings,
                        },
                    },
                },
            })
        end
    end,

    -- -------------------------------------------------------------------------
    -- JDTLS Settings
    -- -------------------------------------------------------------------------
    settings = {
        java = {
            -- Signature help
            signatureHelp = { enabled = true },

            -- Code completion
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
                importOrder = {
                    "java",
                    "javax",
                    "com",
                    "org",
                },
            },

            -- Import organization
            sources = {
                organizeImports = {
                    starThreshold = 9999,
                    staticStarThreshold = 9999,
                },
            },

            -- Code generation templates
            codeGeneration = {
                toString = {
                    template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
                },
                useBlocks = true,
            },

            -- Java runtimes (for project compilation)
            configuration = {
                runtimes = get_sdkman_runtimes(),
            },

            -- Code formatting
            format = {
                enabled = true,
                settings = {
                    url = vim.fn.stdpath("config") .. "/eclipse-formatter.xml",
                },
            },
        },
    },

    -- -------------------------------------------------------------------------
    -- Initialization Options
    -- -------------------------------------------------------------------------
    init_options = {
        bundles = bundles,
    },

    -- -------------------------------------------------------------------------
    -- LSP Protocol Handlers
    -- -------------------------------------------------------------------------
    handlers = {
        ["$/progress"] = function() end,  -- Disable progress reports
    },
}

return opts
