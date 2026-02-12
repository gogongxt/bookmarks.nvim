-- Debug commands for troubleshooting extmark issues
local M = {}
local Tracker = require("bookmarks.tracker")

---Show all tracked extmarks
function M.show_extmarks()
  local result = {}

  -- First, show the raw extmark_map contents
  local extmark_map = Tracker.get_extmark_map()
  if next(extmark_map) == nil then
    table.insert(result, "extmark_map is EMPTY!")
  else
    table.insert(result, "extmark_map contents:")
    for key, extmark_id in pairs(extmark_map) do
      table.insert(result, string.format("  %s -> %d", key, extmark_id))
    end
  end

  table.insert(result, "")

  -- Then check each buffer
  for bufnr = 1, vim.fn.bufnr("$") do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local bookmarks = Tracker.get_buffer_bookmarks(bufnr)
      if #bookmarks > 0 then
        local buf_name = vim.api.nvim_buf_get_name(bufnr)
        table.insert(result, string.format("Buffer %d: %s", bufnr, buf_name))
        for _, bm in ipairs(bookmarks) do
          local line = Tracker.get_current_line_from_extmark(bufnr, bm.bookmark_id)
          table.insert(result, string.format("  Bookmark ID %d -> extmark_id %d -> line %d",
            bm.bookmark_id, bm.extmark_id, line or -1))
        end
      end
    end
  end

  if #result <= 2 then
    table.insert(result, "")
    table.insert(result, "No extmarks found in any buffer")
  end

  vim.notify(table.concat(result, "\n"), vim.log.levels.INFO)
  return result
end

---Show detailed info about a specific bookmark
function M.inspect_bookmark(bookmark_id)
  bookmark_id = bookmark_id or tonumber(vim.fn.input("Bookmark ID: "))

  if not bookmark_id then
    return
  end

  local result = {}
  table.insert(result, string.format("Inspecting bookmark ID: %d", bookmark_id))

  -- Check all buffers
  for bufnr = 1, vim.fn.bufnr("$") do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local extmark_id = Tracker.get_extmark(bufnr, bookmark_id)
      if extmark_id then
        local buf_name = vim.api.nvim_buf_get_name(bufnr)
        local line = Tracker.get_current_line_from_extmark(bufnr, bookmark_id)
        table.insert(result, string.format("  Found in buffer %d (%s)", bufnr, buf_name))
        table.insert(result, string.format("  Extmark ID: %d", extmark_id))
        table.insert(result, string.format("  Current line: %s", tostring(line)))
      end
    end
  end

  if #result == 1 then
    table.insert(result, "  NOT FOUND in any buffer")
  end

  vim.notify(table.concat(result, "\n"), vim.log.levels.INFO)
end

return M
