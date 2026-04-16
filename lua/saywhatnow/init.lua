local M = {}

function M.setup(opts)
end

function M.run(start_line, end_line)
  local git = require("saywhatnow.git")
  local ui = require("saywhatnow.ui")

  if not start_line or not end_line then
    vim.notify("SayWhatNow: Could not determine lines!", vim.log.levels.WARN)
    return
  end

  local filepath = vim.api.nvim_buf_get_name(0)
  local commits = git.get_function_commits(start_line, end_line, filepath)

  if not commits or #commits == 0 then
    vim.notify("SayWhatNow: No git history found for these lines.", vim.log.levels.INFO)
    return
  end

  ui.open_time_machine(commits, filepath, start_line)
end

function M.start_normal()
  local ts = require("saywhatnow.treesitter")
  local start_line, end_line = ts.get_function_range()

  if not start_line then
    vim.notify("SayWhatNow: Cursor is not inside a function! Use Visual Selection instead.", vim.log.levels.WARN)
    return
  end

  M.run(start_line, end_line)
end

function M.start_visual()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

  vim.schedule(function()
    local start_line = vim.fn.line("'<")
    local end_line = vim.fn.line("'>")
    M.run(start_line, end_line)
  end)
end

return M
