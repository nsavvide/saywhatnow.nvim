local M = {}

function M.get_function_commits(start_line, end_line, filepath)
  local cmd = {
    "git",
    "log",
    string.format("-L%d,%d:%s", start_line, end_line, filepath),
    "--pretty=format:COMMIT:%H|%s|%cr"
  }

  local obj = vim.system(cmd, { text = true }):wait()

  if obj.code ~= 0 then
    vim.notify("SayWhatNow: Git error -> " .. (obj.stderr or "Unknown"), vim.log.levels.ERROR)
    return nil
  end

  local commits = {}

  for line in string.gmatch(obj.stdout, "[^\r\n]+") do
    if line:match("^COMMIT:") then
      local hash, msg, date = line:match("^COMMIT:([^|]+)|([^|]+)|([^|]+)")
      if hash then
        table.insert(commits, {
          hash = hash,
          msg = msg,
          date = date
        })
      end
    end
  end

  return commits
end

return M
