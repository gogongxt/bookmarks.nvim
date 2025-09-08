local M = {}
local Service = require("bookmarks.domain.service")

-- Try to load telescope modules (will be nil if not available)
local has_telescope, _ = pcall(require, "telescope")
local action_state, actions

if has_telescope then
  action_state = require("telescope.actions.state")
  actions = require("telescope.actions")
end

-- Helper function to get selected bookmark (works for both telescope and snacks)
local function get_selected_bookmark(picker, selection)
  -- Handle snacks picker
  if type(picker) == "table" and picker.selected then
    local selected_items = picker:selected({ fallback = true })
    if #selected_items > 0 then
      return selected_items[1].bookmark
    end
    -- If no item is selected, try to get the current target
    local current_item = picker.list:get_target()
    if current_item and current_item.bookmark then
      return current_item.bookmark
    end
    return nil
  end

  -- Handle direct selection (from snacks)
  if selection then
    return type(selection) == "table" and selection.bookmark or selection
  end

  -- Fallback to telescope
  if has_telescope and action_state then
    local telescope_selection = action_state.get_selected_entry()
    if not telescope_selection then
      return nil
    end
    return telescope_selection.value
  end

  return nil
end

-- Close picker (works for both telescope and snacks)
local function close_picker(picker, prompt_bufnr)
  -- Handle snacks picker (table with close method)
  if type(picker) == "table" and picker.close then
    picker:close()
    return
  end

  -- Fallback to telescope
  if has_telescope and actions and type(prompt_bufnr) == "number" then
    actions.close(prompt_bufnr)
  end

  -- Return without closing to maintain picker open after actions
  return
end

-- Go to bookmark location
function M.goto_bookmark(picker, selection)
  local bookmark = get_selected_bookmark(picker, selection)
  if not bookmark then
    return
  end

  close_picker(picker)
  Service.goto_bookmark(bookmark.id)
end

-- Open bookmark in new tab
function M.open_in_new_tab(picker, selection)
  local bookmark = get_selected_bookmark(picker, selection)
  if not bookmark then
    return
  end

  close_picker(picker)
  Service.goto_bookmark(bookmark.id, { cmd = "tabnew" })
end

-- Open bookmark in vertical split
function M.open_in_vsplit(picker, selection)
  local bookmark = get_selected_bookmark(picker, selection)
  if not bookmark then
    return
  end

  close_picker(picker)
  Service.goto_bookmark(bookmark.id, { cmd = "vsplit" })
end

-- Open bookmark in horizontal split
function M.open_in_split(picker, selection)
  local bookmark = get_selected_bookmark(picker, selection)
  if not bookmark then
    return
  end

  close_picker(picker)
  Service.goto_bookmark(bookmark.id, { cmd = "split" })
end

-- Delete bookmark
function M.delete(picker, selection)
  local bookmark = get_selected_bookmark(picker, selection)
  if not bookmark then
    return
  end

  Service.delete_node(bookmark.id)
  close_picker(picker)
end

return M
