local M = {}

-- Create a namespace for our ghost text
local ns_blame = vim.api.nvim_create_namespace("saywhatnow_blame")

local state = {
  commits = {},
  current_idx = 1,
  left_win = nil,
  left_buf = nil,
  right_win = nil,
  right_buf = nil,
  filepath = nil,
  rel_path = nil,
  start_line = 1
}

local function render_commit()
  local commit = state.commits[state.current_idx]
  local cwd = vim.fn.fnamemodify(state.filepath, ":p:h")

  -- 1. Fetch the file content at this specific commit
  local cmd = { "git", "--no-pager", "show", commit.hash .. ":" .. state.rel_path }
  local obj = vim.system(cmd, { text = true, cwd = cwd }):wait()

  -- IF GIT FAILS TO FIND THE FILE (e.g., file renamed or didn't exist yet)
  if obj.code ~= 0 then
    -- Create a friendly fallback message instead of crashing
    local fallback_lines = {
      "/* ",
      " * SayWhatNow: File not found at this path in this commit.",
      " *",
      " * This usually means the file was renamed, moved, ",
      " * or did not exist yet at the current path.",
      " *",
      " * Git Error: " .. vim.trim(obj.stderr or "Unknown"),
      " */"
    }
    
    vim.api.nvim_set_option_value("modifiable", true, { buf = state.right_buf })
    vim.api.nvim_buf_set_lines(state.right_buf, 0, -1, false, fallback_lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = state.right_buf })
    
    -- Clear any leftover ghost text from the previous commit
    vim.api.nvim_buf_clear_namespace(state.right_buf, ns_blame, 0, -1)

    -- Update the winbar so the user still knows what commit they are stuck on
    local short_msg = string.sub(commit.msg, 1, 40)
    if #commit.msg > 40 then short_msg = short_msg .. "..." end
    local right_winbar = string.format(" %%#WarningMsg#%s%%* - %s (%s)", string.sub(commit.hash, 1, 7), short_msg, commit.date)
    vim.api.nvim_set_option_value("winbar", right_winbar, { win = state.right_win })
    
    return -- Stop executing the rest of the render function
  end

  -- IF GIT SUCCEEDS
  local lines = {}
  for line in string.gmatch(obj.stdout, "([^\n]*)\n?") do
    table.insert(lines, line)
  end
  if lines[#lines] == "" then table.remove(lines, #lines) end

  vim.api.nvim_set_option_value("modifiable", true, { buf = state.right_buf })
  vim.api.nvim_buf_set_lines(state.right_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = state.right_buf })

  -- 2. Fetch and parse git blame for the ghost text (using absolute filepath to avoid 128 error)
  local blame_cmd = { "git", "blame", "--porcelain", commit.hash, "--", state.filepath }
  local blame_obj = vim.system(blame_cmd, { text = true, cwd = cwd }):wait()

  vim.api.nvim_buf_clear_namespace(state.right_buf, ns_blame, 0, -1)

  if blame_obj.code == 0 then
    local parsed_commits = {}
    local line_idx = 0
    local current_hash = nil

    for b_line in string.gmatch(blame_obj.stdout, "[^\r\n]+") do
      local hash_match = string.match(b_line, "^([0-9a-f]+) %d+ %d+")

      if hash_match then
        current_hash = hash_match
        if not parsed_commits[current_hash] then
          parsed_commits[current_hash] = { author = "Unknown", summary = "" }
        end
      elseif string.match(b_line, "^author ") then
        parsed_commits[current_hash].author = string.sub(b_line, 8)
      elseif string.match(b_line, "^summary ") then
        parsed_commits[current_hash].summary = string.sub(b_line, 9)
      elseif string.match(b_line, "^\t") then
        local code_line = string.sub(b_line, 2)

        -- Skip drawing ghost text for empty lines to reduce UI clutter
        if vim.trim(code_line) ~= "" then
          local data = parsed_commits[current_hash]
          local display_summary = data.summary

          if #display_summary > 30 then
            display_summary = string.sub(display_summary, 1, 27) .. "..."
          end

          -- Match on the first 7 chars to avoid hidden whitespace bugs
          local is_current = (string.sub(current_hash, 1, 7) == string.sub(commit.hash, 1, 7))
          local hl_group = is_current and "String" or "Comment"
          local prefix = is_current and "★ " or "  "

          local vt_text = string.format("%s%s: %s", prefix, data.author, display_summary)

          local extmark_opts = {
            virt_text = { { vt_text, hl_group } },
            virt_text_pos = "eol",
          }

          -- Highlight the background of the exact lines changed in this commit
          if is_current then
            extmark_opts.line_hl_group = "Visual"
          end

          vim.api.nvim_buf_set_extmark(state.right_buf, ns_blame, line_idx, 0, extmark_opts)
        end

        -- Always increment the line index so ghost text doesn't misalign!
        line_idx = line_idx + 1
      end
    end
  end

  -- 3. UI and Winbar Updates
  local short_msg = string.sub(commit.msg, 1, 40)
  if #commit.msg > 40 then short_msg = short_msg .. "..." end
  local right_winbar = string.format(" %%#WarningMsg#%s%%* - %s (%s)", string.sub(commit.hash, 1, 7), short_msg, commit.date)
  vim.api.nvim_set_option_value("winbar", right_winbar, { win = state.right_win })

  local max_lines = vim.api.nvim_buf_line_count(state.right_buf)
  local safe_line = math.min(state.start_line, max_lines)
  pcall(vim.api.nvim_win_set_cursor, state.right_win, { safe_line, 0 })

  vim.cmd("diffupdate")
end

local function older_commit()
  if state.current_idx < #state.commits then
    state.current_idx = state.current_idx + 1
    render_commit()
  else
    vim.notify("SayWhatNow: Oldest commit reached.", vim.log.levels.WARN)
  end
end

local function newer_commit()
  if state.current_idx > 1 then
    state.current_idx = state.current_idx - 1
    render_commit()
  else
    vim.notify("SayWhatNow: Newest commit reached.", vim.log.levels.WARN)
  end
end

local function show_help()
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = {
    " SayWhatNow Keybinds ",
    " ---------------------- ",
    "  H  : Scrub Backward in Time (Older) ",
    "  L  : Scrub Forward in Time (Newer)  ",
    "  q  : Close Time Machine             ",
    "  ?  : Show this help menu            ",
    " ",
    " (Press 'q' or '<Esc>' to close)      "
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = 40
  local height = #lines
  local ui = vim.api.nvim_list_uis()[1]

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((ui.width / 2) - (width / 2)),
    row = math.floor((ui.height / 2) - (height / 2)),
    style = "minimal",
    border = "rounded"
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  vim.keymap.set("n", "q", function() pcall(vim.api.nvim_win_close, win, true) end, { buffer = buf, noremap = true, silent = true })
  vim.keymap.set("n", "<Esc>", function() pcall(vim.api.nvim_win_close, win, true) end, { buffer = buf, noremap = true, silent = true })
end

function M.open_time_machine(commits, filepath, start_line)
  state.commits = commits
  state.filepath = filepath
  state.start_line = start_line
  state.current_idx = 1

  state.left_win = vim.api.nvim_get_current_win()
  state.left_buf = vim.api.nvim_win_get_buf(state.left_win)

  local original_winbar = vim.api.nvim_get_option_value("winbar", { win = state.left_win })
  vim.api.nvim_set_option_value("winbar", " %#String#Current State (Local)%*", { win = state.left_win })

  local cwd = vim.fn.fnamemodify(filepath, ":p:h")
  local rel_path_obj = vim.system({ "git", "ls-files", "--full-name", filepath }, { text = true, cwd = cwd }):wait()
  state.rel_path = vim.trim(rel_path_obj.stdout)

  vim.cmd("vsplit")
  state.right_win = vim.api.nvim_get_current_win()
  state.right_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(state.right_win, state.right_buf)

  local ft = vim.api.nvim_get_option_value("filetype", { buf = state.left_buf })
  vim.api.nvim_set_option_value("filetype", ft, { buf = state.right_buf })

  render_commit()

  vim.api.nvim_set_current_win(state.left_win)
  vim.cmd("diffthis")
  vim.api.nvim_set_current_win(state.right_win)
  vim.cmd("diffthis")

  for _, buf in ipairs({ state.left_buf, state.right_buf }) do
    local opts = { buffer = buf, noremap = true, silent = true }
    vim.keymap.set("n", "H", older_commit, vim.tbl_extend("force", opts, { desc = "Scrub backward" }))
    vim.keymap.set("n", "L", newer_commit, vim.tbl_extend("force", opts, { desc = "Scrub forward" }))
    vim.keymap.set("n", "?", show_help, vim.tbl_extend("force", opts, { desc = "Show Help" }))
  end

  vim.keymap.set("n", "q", "<cmd>q<CR>", { buffer = state.right_buf, noremap = true, silent = true })

  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = state.right_buf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(state.left_win) then
        vim.api.nvim_win_call(state.left_win, function()
          vim.cmd("diffoff")
          pcall(vim.api.nvim_set_option_value, "winbar", original_winbar, { win = state.left_win })
        end)
      end
      pcall(vim.keymap.del, "n", "H", { buffer = state.left_buf })
      pcall(vim.keymap.del, "n", "L", { buffer = state.left_buf })
      pcall(vim.keymap.del, "n", "?", { buffer = state.left_buf })
    end
  })
end

return M
