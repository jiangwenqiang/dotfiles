-- JDTLS configuration helpers
-- Provides methods to build JDTLS LSP configuration

local M = {}

--- Path to SDKMAN Java installations
M.SDKMAN_JAVA_PATH = vim.fn.expand("~/.sdkman/candidates/java")

--- Minimum Java version required for JDTLS
M.MIN_JAVA_VERSION = 21

--- Markers for multi-module projects (Maven/Gradle multi-module, monorepo)
M.ROOT_MARKERS_MULTI = { "mvnw", "gradlew", "settings.gradle", "settings.gradle.kts", ".git" }

--- Markers for single-module projects
M.ROOT_MARKERS_SINGLE = { "build.xml", "pom.xml", "build.gradle", "build.gradle.kts" }

--- Check if a directory contains any of the given markers
---@param dirpath string Directory path to check
---@param markers string[] List of marker filenames
---@return boolean has_marker True if any marker exists
local function has_any_marker(dirpath, markers)
    for _, marker in ipairs(markers) do
        if vim.fn.filereadable(dirpath .. "/" .. marker) == 1 then
            return true
        end
    end
    return false
end

--- Discover all Java runtimes from SDKMAN installation
---@return table[] Array of runtime configurations with {name, path}
function M.get_sdkman_runtimes()
    if vim.fn.isdirectory(M.SDKMAN_JAVA_PATH) == 0 then
        return {}
    end

    local entries = vim.fn.readdir(M.SDKMAN_JAVA_PATH)
    local runtimes = {}

    -- Sort by version number (highest first)
    table.sort(entries, function(a, b)
        return tonumber(a:match("^(%d+)") or 0) > tonumber(b:match("^(%d+)") or 0)
    end)

    for _, entry in ipairs(entries) do
        if entry ~= "current" and vim.fn.isdirectory(M.SDKMAN_JAVA_PATH .. "/" .. entry) == 1 then
            local java_major = entry:match("^(%d+)%.")
            if java_major then
                -- Java 8 uses special naming convention
                local runtime_name = java_major == "8" and "JavaSE-1.8" or ("JavaSE-" .. java_major)
                table.insert(runtimes, {
                    name = runtime_name,
                    path = M.SDKMAN_JAVA_PATH .. "/" .. entry,
                })
            end
        end
    end

    return runtimes
end

--- Get the Java executable path from available runtimes
---@param runtimes table[] Array of runtime configurations
---@return string executable Path to Java binary
---@errorThrows if no runtimes found or version too low
function M.get_java_executable(runtimes)
    if #runtimes == 0 then
        error("No Java runtimes found in SDKMAN. Please install Java 21: sdk install java 21.0.10-tem")
    end

    local highest = runtimes[1]
    local major_version = tonumber(highest.name:match("JavaSE%-(%d+)"))

    if major_version and major_version >= M.MIN_JAVA_VERSION then
        return highest.path .. "/bin/java"
    else
        error(string.format(
            "JDTLS requires Java %d or higher, but found: %s\nPlease install: sdk install java 21.0.10-tem",
            M.MIN_JAVA_VERSION,
            highest.name
        ))
    end
end

--- Get platform-specific config area name for JDTLS
---@return string config_name Config directory name (e.g., "config_mac_arm")
function M.get_config_area_name()
    local os_name = vim.loop.os_uname().sysname
    local arch = vim.loop.os_uname().machine

    local config_map = {
        Darwin = {
            arm64 = "config_mac_arm",
            x86_64 = "config_mac",
        },
        Linux = {
            aarch64 = "config_linux_arm",
            x86_64 = "config_linux",
        },
        Windows_NT = {
            x86_64 = "config_win",
        },
    }

    return config_map[os_name] and config_map[os_name][arch] or "config_mac"
end

--- Extract Maven settings path from .mvn/maven.config
---@param project_root string Path to project root
---@return string|nil settings_path Absolute path to settings.xml, or nil if not found
function M.get_maven_settings(project_root)
    if not project_root then
        return nil
    end

    local config_file = project_root .. "/.mvn/maven.config"
    if vim.fn.filereadable(config_file) ~= 1 then
        return nil
    end

    -- Parse maven.config for --settings flag
    for _, line in ipairs(vim.fn.readfile(config_file)) do
        local settings_path = line:match("%-%-settings%s*=%s*(%S+)")
            or line:match("%-%-settings%s+(%S+)")
            or line:match("%-s%s+(%S+)")

        if settings_path then
            settings_path = settings_path:gsub("^['\"]", ""):gsub("['\"]$", "")
            -- Convert relative path to absolute
            if not vim.startswith(settings_path, "/") and not vim.startswith(settings_path, "~") then
                return project_root .. "/" .. settings_path
            end
            return vim.fn.expand(settings_path)
        end
    end

    return nil
end

--- Get workspace directory for JDTLS
---@param project_root string|nil Path to project root
---@return string workspace_dir Path to JDTLS workspace cache
function M.get_workspace_dir(project_root)
    local jdtls_cache_root = vim.fn.stdpath("cache") .. "/jdtls"

    if project_root then
        -- Use hash to create unique workspace per project
        local project_hash = vim.fn.sha256(project_root)
        return jdtls_cache_root .. "/workspace/" .. project_hash
    end

    return jdtls_cache_root .. "/workspace"
end

--- Get root markers for LSP configuration
---@return table|string[] markers Markers for nvim-lspconfig
function M.get_root_markers()
    -- nvim 0.11.3+ supports nested markers array
    if vim.fn.has("nvim-0.11.3") == 1 then
        return { M.ROOT_MARKERS_MULTI, M.ROOT_MARKERS_SINGLE }
    end
    -- Older versions require flattened array
    return vim.list_extend(M.ROOT_MARKERS_MULTI, M.ROOT_MARKERS_SINGLE)
end

--- Find project root by searching for marker files
---@param filepath string|nil Path to current file
---@return string|nil root_dir Project root directory, or nil if not found
function M.find_project_root(filepath)
    local has_filepath = filepath and filepath ~= ""

    -- Fall back to current directory if no filepath provided
    if not has_filepath then
        local cwd = vim.fn.getcwd()
        if M.is_project_directory(cwd) then
            return cwd
        end
    end

    -- First try multi-module markers (finds repo root in monorepos)
    local root = vim.fs.root(filepath, M.ROOT_MARKERS_MULTI)
    if root then
        return root
    end

    -- Then try single-module markers
    root = vim.fs.root(filepath, M.ROOT_MARKERS_SINGLE)
    if root then
        return root
    end

    return nil
end

--- Check if a directory is a valid Java project directory
---@param dirpath string Directory path to check
---@return boolean is_project True if directory contains project markers
function M.is_project_directory(dirpath)
    return has_any_marker(dirpath, M.ROOT_MARKERS_MULTI) or has_any_marker(dirpath, M.ROOT_MARKERS_SINGLE)
end

return M
