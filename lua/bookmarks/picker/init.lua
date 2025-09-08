local M = {}

-- Lazy load the appropriate picker module based on config
local function get_picker_module()
  local picker_type = vim.g.bookmarks_config.picker.type or "telescope"

  if picker_type == "snacks" then
    return {
      pick_bookmark = require("bookmarks.picker.snacks.bookmark-picker").pick_bookmark,
      grep_bookmark = require("bookmarks.picker.snacks.bookmark-picker").grep_bookmark,
      pick_bookmark_list = require("bookmarks.picker.snacks.list-picker").pick_bookmark_list,
      pick_commands = require("bookmarks.picker.snacks.command-picker").pick_commands,
    }
  else
    return {
      pick_bookmark = require("bookmarks.picker.bookmark-picker").pick_bookmark,
      grep_bookmark = require("bookmarks.picker.bookmark-picker").grep_bookmark,
      pick_bookmark_list = require("bookmarks.picker.list-picker").pick_bookmark_list,
      pick_commands = require("bookmarks.picker.command-picker").pick_commands,
    }
  end
end

-- Create wrapper functions that delegate to the appropriate picker
function M.pick_bookmark(callback, opts)
  local picker_module = get_picker_module()
  return picker_module.pick_bookmark(callback, opts)
end

function M.grep_bookmark(opts)
  local picker_module = get_picker_module()
  return picker_module.grep_bookmark(opts)
end

function M.pick_bookmark_list(callback, opts)
  local picker_module = get_picker_module()
  return picker_module.pick_bookmark_list(callback, opts)
end

function M.pick_commands(opts)
  local picker_module = get_picker_module()
  return picker_module.pick_commands(opts)
end

return M
