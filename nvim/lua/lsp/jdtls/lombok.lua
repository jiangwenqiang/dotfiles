local M = {}

M.DEFAULT_VERSION = "1.18.42"
M.DOWNLOAD_URL = "https://projectlombok.org/downloads/lombok-%s.jar"
M.EDGE_URL = "https://projectlombok.org/lombok-edge.jar"

---@param root string
local function ensure_dir(root)
    if vim.fn.isdirectory(root) == 0 then
        vim.fn.mkdir(root, "p")
    end
end

---@param jar_path string
---@return boolean
local function is_valid_jar(jar_path)
    return vim.fn.filereadable(jar_path) == 1 and vim.fn.getfsize(jar_path) > 0
end

---@param paths string[]
---@return string|nil
local function pick_first_valid(paths)
    for _, path in ipairs(paths) do
        if is_valid_jar(path) then
            return path
        end
    end
    return nil
end

---@param jdtls_root string
---@param lombok_dir string
---@return string|nil
local function find_existing_jar(jdtls_root, lombok_dir)
    local root_lombok_jar = vim.fs.joinpath(jdtls_root, "lombok.jar")
    local direct_hit = pick_first_valid({ root_lombok_jar })
    if direct_hit then
        return direct_hit
    end

    local matches = vim.fn.glob(vim.fs.joinpath(lombok_dir, "lombok*.jar"), false, true)
    table.sort(matches)
    return pick_first_valid(matches)
end

---@param url string
---@param out string
---@return boolean
local function download_with(url, out)
    local cmd
    if vim.fn.executable("curl") == 1 then
        cmd = { "curl", "-fL", url, "-o", out }
    elseif vim.fn.executable("wget") == 1 then
        cmd = { "wget", "-O", out, url }
    else
        return false
    end

    local result = vim.system(cmd, { text = true }):wait()
    return result.code == 0 and is_valid_jar(out)
end

---@param opts? {jdtls_root?: string, version?: string}
---@return string|nil jar_path
function M.ensure(opts)
    opts = opts or {}
    local jdtls_root = opts.jdtls_root or (vim.fn.stdpath("data") .. "/mason/packages/jdtls")
    local version = opts.version or M.DEFAULT_VERSION
    local lombok_dir = vim.fs.joinpath(jdtls_root, "lombok")

    local existing_jar = find_existing_jar(jdtls_root, lombok_dir)
    if existing_jar then
        return existing_jar
    end

    ensure_dir(lombok_dir)

    local jar_path = vim.fs.joinpath(lombok_dir, ("lombok-%s.jar"):format(version))
    local url = version == "nightly" and M.EDGE_URL or M.DOWNLOAD_URL:format(version)
    if download_with(url, jar_path) then
        return jar_path
    end

    vim.notify("[jdtls] Failed to download lombok from " .. url, vim.log.levels.WARN)
    return nil
end

return M
