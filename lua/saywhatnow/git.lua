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

function M.get_pr_number(commit_hash, commit_msg)
  -- Fast path: PR number embedded in commit message
  local pr_num = commit_msg:match("%(#(%d+)%)")
  if not pr_num then
    pr_num = commit_msg:match("[Mm]erge pull request #(%d+)")
  end
  if pr_num then return pr_num end

  -- Fallback: ask gh CLI (squash merges that don't embed the PR#)
  local obj = vim.system(
    { "gh", "pr", "list", "--search", "SHA:" .. commit_hash, "--state", "merged", "--json", "number", "--limit", "1" },
    { text = true }
  ):wait()

  if obj.code == 0 and obj.stdout and obj.stdout ~= "" and obj.stdout ~= "[]\n" and obj.stdout ~= "[]" then
    local ok, data = pcall(vim.json.decode, obj.stdout)
    if ok and data and #data > 0 then
      return tostring(data[1].number)
    end
  end

  return nil
end

return M
