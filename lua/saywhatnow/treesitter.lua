local M = {}

function M.get_function_range()
  local node = vim.treesitter.get_node()

  while node do
    local node_type = node:type()

    if string.match(node_type, "function") or string.match(node_type, "method") then
      local start_row, _, end_row, _ = node:range()

      return start_row + 1, end_row + 1
    end

    node = node:parent()
  end

  return nil, nil
end

return M
