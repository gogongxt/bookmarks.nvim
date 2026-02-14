local Repo = require("bookmarks.domain.repo")
local Node = require("bookmarks.domain.node")
local Tracker = require("bookmarks.tracker")
local ns_name = "BookmarksNvim"
local hl_name = "BookmarksNvimSign"
local hl_name_line = "BookmarksNvimLine"
local ns = vim.api.nvim_create_namespace(ns_name)

---@class Signs
---@field enable_auto_line_adjust boolean
---@field mark Sign
---@field desc_format function(string):string

---@class Sign
---@field icon string
---@field color? string
---@field line_bg? string

local M = {}

-- Track whether bookmark signs are enabled
M.enabled = true

---@param signs Signs
function M.setup(signs)
  local mark = signs.mark
  vim.fn.sign_define(hl_name, { text = mark.icon, texthl = hl_name })
  if mark.color then
    vim.api.nvim_set_hl(0, hl_name, { fg = mark.color })
  end
  if mark.line_bg then
    vim.api.nvim_set_hl(0, hl_name_line, { bg = mark.line_bg })
  end
end

---Enable bookmark signs display
function M.enable()
  M.enabled = true
  M.safe_refresh_signs()
end

---Disable bookmark signs display
function M.disable()
  M.enabled = false
  M.clean()
end

---Toggle bookmark signs display
---@return boolean new_state - The new enabled state
function M.toggle()
  if M.enabled then
    M.disable()
  else
    M.enable()
  end
  return M.enabled
end

---Check if bookmark signs are enabled
---@return boolean
function M.is_enabled()
  return M.enabled
end

---@param line number
---@param buf_number number
---@param desc string
---@param bookmark_id number? Optional bookmark ID for extmark tracking
function M.place_sign(line, buf_number, desc, bookmark_id)
  -- Determine the actual line to use for sign placement
  local actual_line = line

  -- If auto line adjust is enabled and bookmark_id is provided,
  -- check if there's an existing tracking extmark and use its position
  if bookmark_id and vim.g.bookmarks_config and vim.g.bookmarks_config.signs.enable_auto_line_adjust then
    if vim.g.bookmarks_debug then
      vim.notify(string.format("[DEBUG Sign] place_sign: bufnr=%d, bookmark_id=%d, line=%d",
        buf_number, bookmark_id, line), vim.log.levels.INFO)
    end

    local extmark_line = Tracker.get_current_line_from_extmark(buf_number, bookmark_id)
    if extmark_line then
      -- Use the extmark's current position instead of the stored line
      actual_line = extmark_line
      if vim.g.bookmarks_debug then
        vim.notify(string.format("[DEBUG Sign] place_sign: using extmark position %d (stored was %d)",
          actual_line, line), vim.log.levels.INFO)
      end
    else
      if vim.g.bookmarks_debug then
        vim.notify("[DEBUG Sign] place_sign: extmark not found", vim.log.levels.WARN)
      end
    end
  end

  -- Place the sign at the actual line
  vim.fn.sign_place(actual_line, ns_name, hl_name, buf_number, { lnum = actual_line })
  local at_end = -1
  local row = actual_line - 1
  vim.api.nvim_buf_set_extmark(buf_number, ns, row, at_end, {
    virt_text = { { "" .. desc, hl_name } },
    virt_text_pos = "eol",
    hl_group = hl_name,
    hl_mode = "combine",
    priority = 1000, -- Higher priority ensures bookmark appears before other virtual text
  })

  -- Get the length of the current line
  local line_length = #(vim.api.nvim_buf_get_lines(buf_number, row, row + 1, false)[1] or "")
  vim.api.nvim_buf_set_extmark(buf_number, ns, actual_line - 1, 0, {
    end_row = row,
    end_col = line_length,
    hl_group = hl_name_line,
  })

  -- Create tracking extmark at the actual position (only if doesn't exist)
  if bookmark_id and vim.g.bookmarks_config and vim.g.bookmarks_config.signs.enable_auto_line_adjust then
    local existing_extmark_id = Tracker.get_extmark(buf_number, bookmark_id)
    if not existing_extmark_id then
      -- Create tracking extmark only if it doesn't exist
      -- Once created, it will automatically follow content edits
      local extmark_id = Tracker.create_tracking_extmark(buf_number, actual_line, 0, bookmark_id)
      if not extmark_id then
        vim.notify(string.format("[Bookmarks] Failed to create tracking extmark at line %d for bookmark %d in buffer %s",
          actual_line, bookmark_id, vim.api.nvim_buf_get_name(buf_number)), vim.log.levels.WARN)
      end
    end
  end
end

function M.clean()
  pcall(vim.fn.sign_unplace, ns_name)
  local all = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
  for _, extmark in ipairs(all) do
    vim.api.nvim_buf_del_extmark(0, ns, extmark[1])
  end

  -- Optionally remove line highlights here
  for _, line_ind in ipairs(all) do
    -- Assume desc can provide the unique identifier. You may consider further adjustments based on your logic.
    -- local hl_line_name = "BookmarksNvimLine" .. line_ind[3]  -- Extract the correct identifier for cleanup
    vim.api.nvim_buf_clear_namespace(0, ns, line_ind[1] - 1, line_ind[1])
  end
end

---@param bookmarks? Bookmarks.Node[]
function M._refresh_signs(bookmarks)
  M.clean()

  -- Don't show signs if disabled
  if not M.enabled then
    return
  end

  local active_list = Repo.ensure_and_get_active_list()

  bookmarks = bookmarks or Node.get_all_bookmarks(active_list)
  local buf_number = vim.api.nvim_get_current_buf()
  local filepath = vim.fn.expand("%:p")
  for _, bookmark in ipairs(bookmarks) do
    if filepath == bookmark.location.path then
      -- Get display text: first line of description (for Desc) or name (for Mark)
      local display_text
      if bookmark.description and bookmark.description ~= "" then
        display_text = bookmark.description:match("[^\n]+") or bookmark.description
      else
        display_text = bookmark.name or ""
      end
      local desc = bookmark.order .. ": " .. display_text
      pcall(M.place_sign, bookmark.location.line, buf_number, desc, bookmark.id)
    end
  end
end

---@param bookmarks? Bookmarks.Node[]
function M.safe_refresh_signs(bookmarks)
  pcall(M._refresh_signs, bookmarks)
end

return M
