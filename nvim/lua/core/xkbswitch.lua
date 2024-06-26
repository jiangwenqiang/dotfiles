local M = {
  nlang = "com.apple.keylayout.ABC",
  langs = {},
}

M.config = function(opts)
  if opts.nlang then
    M.nlang = opts.nlang
  end
  local user_config_dir = get_config_dir()
  local group = vim.api.nvim_create_augroup("xkbswitch", { clear = true })
  local xkbswitch = join_paths(user_config_dir, "bin", "xkbswitch")
  vim.api.nvim_create_autocmd({ "InsertEnter" }, {
    group = group,
    callback = function(args)
      if not M.langs[args.buf] then
        return
      end

      if M.langs[args.buf] then
        vim.fn.jobstart({ xkbswitch, M.langs[args.buf] }, {
          on_stderr = function()
            M.langs[args.buf] = nil
          end,
        })
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "InsertLeave" }, {
    group = group,
    callback = function(args)
      vim.fn.jobstart({ xkbswitch }, {
        stdout_buffered = true,
        on_stdout = function(_, lang)
          M.langs[args.buf] = lang[1]
          vim.fn.jobstart({ xkbswitch, M.nlang })
        end,
      })
    end,
  })
end

return M
