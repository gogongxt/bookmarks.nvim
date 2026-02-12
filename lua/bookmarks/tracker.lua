--- Runtime extmark tracking for automatic line number adjustment
--- Maintains in-memory mapping: buffer_path + bookmark_id -> extmark_id
--- Does NOT persist to JSON - extmarks are recreated when files are loaded

local M = {}

-- Key: "buffer_path:bookmark_id", Value: extmark_id
local extmark_map = {}

-- Namespace for bookmark tracking extmarks
local ns_id = vim.api.nvim_create_namespace("BookmarksTracker")

---Normalize buffer path to ensure consistent key generation
---Always returns absolute path to avoid issues with relative/absolute path mismatches
---@param bufnr number Buffer number
---@return string Normalized absolute path
local function normalize_buf_path(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  -- Convert to absolute path and resolve symlinks
  -- IMPORTANT: Must match the normalization in service.lua (update_bookmark_positions_from_extmarks)
  return vim.fn.resolve(vim.fn.fnamemodify(path, ":p"))
end

---Generate consistent key for extmark tracking
---@param buf_path string Normalized buffer path
---@param bookmark_id number Bookmark ID
---@return string Tracking key
local function make_key(buf_path, bookmark_id)
  return buf_path .. ":" .. tostring(bookmark_id)
end

---Store extmark reference for a bookmark
---@param bufnr number Buffer number
---@param bookmark_id number Bookmark ID
---@param extmark_id number Extmark ID
function M.track_extmark(bufnr, bookmark_id, extmark_id)
  local buf_path = normalize_buf_path(bufnr)
  local key = make_key(buf_path, bookmark_id)
  extmark_map[key] = extmark_id

  if vim.g.bookmarks_debug then
    vim.notify(string.format("[DEBUG Tracker] Tracked extmark: %s -> %d", key, extmark_id), vim.log.levels.INFO)
  end
end

---Get stored extmark ID for a bookmark
---@param bufnr number Buffer number
---@param bookmark_id number Bookmark ID
---@return number|nil extmark_id
function M.get_extmark(bufnr, bookmark_id)
  local raw_path = vim.api.nvim_buf_get_name(bufnr)
  local buf_path = normalize_buf_path(bufnr)
  local key = make_key(buf_path, bookmark_id)

  -- Debug: show what keys exist in the map
  if vim.g.bookmarks_debug then
    local existing_keys = {}
    for k, v in pairs(extmark_map) do
      table.insert(existing_keys, k)
    end
    vim.notify(string.format("[DEBUG Tracker] get_extmark: raw_path=%s", raw_path), vim.log.levels.INFO)
    vim.notify(string.format("[DEBUG Tracker] get_extmark: normalized=%s", buf_path), vim.log.levels.INFO)
    vim.notify(string.format("[DEBUG Tracker] get_extmark: looking for key=%s", key), vim.log.levels.INFO)
    vim.notify(string.format("[DEBUG Tracker] get_extmark: existing keys: %s",
      table.concat(existing_keys, ", ")), vim.log.levels.INFO)

    -- Check if key exists
    if extmark_map[key] then
      vim.notify(string.format("[DEBUG Tracker] get_extmark: FOUND! extmark_id=%s", tostring(extmark_map[key])), vim.log.levels.INFO)
    else
      vim.notify("[DEBUG Tracker] get_extmark: NOT FOUND!", vim.log.levels.WARN)
    end
  end

  return extmark_map[key]
end

---Remove tracking for a bookmark
---@param bufnr number Buffer number
---@param bookmark_id number Bookmark ID
function M.untrack(bufnr, bookmark_id)
  local buf_path = normalize_buf_path(bufnr)
  local key = make_key(buf_path, bookmark_id)
  extmark_map[key] = nil
end

---Get current line number from extmark
---@param bufnr number Buffer number
---@param bookmark_id number Bookmark ID
---@return number|nil line_number Current line number from extmark, or nil if not found
function M.get_current_line_from_extmark(bufnr, bookmark_id)
  local extmark_id = M.get_extmark(bufnr, bookmark_id)
  if not extmark_id then
    if vim.g.bookmarks_debug then
      vim.notify(string.format("[DEBUG Tracker] get_current_line: extmark_id is nil for bookmark %d in buffer %s",
        bookmark_id, vim.api.nvim_buf_get_name(bufnr)), vim.log.levels.WARN)
    end
    return nil
  end

  local extmark = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, extmark_id, {})
  if not extmark or #extmark == 0 then
    if vim.g.bookmarks_debug then
      vim.notify(string.format("[DEBUG Tracker] get_current_line: buf_get_extmark_by_id failed for extmark_id %d", extmark_id), vim.log.levels.WARN)
    end
    return nil
  end

  -- extmark returns [row, col], row is 0-based
  local line = extmark[1] + 1
  return line
end

---Create tracking extmark for a bookmark
---@param bufnr number Buffer number
---@param line number 1-based line number
---@param col number 0-based column number
---@param bookmark_id number Bookmark ID
---@param force boolean? If true, delete old extmark and create new one. If false/nil, only create if doesn't exist
---@return number|nil extmark_id Returns nil if failed
function M.create_tracking_extmark(bufnr, line, col, bookmark_id, force)
  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify(string.format("[Tracker] Failed to create extmark: buffer %d is invalid", bufnr), vim.log.levels.WARN)
    return nil
  end

  -- extmarks are 0-based
  local row = line - 1

  -- Check if line exists in buffer
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if row < 0 or row >= line_count then
    vim.notify(string.format("[Tracker] Failed to create extmark: line %d (row %d) out of bounds (buffer has %d lines)",
      line, row, line_count), vim.log.levels.WARN)
    return nil
  end

  -- Check if extmark already exists
  local old_extmark_id = M.get_extmark(bufnr, bookmark_id)
  if old_extmark_id then
    if force then
      -- Delete old extmark and create new one
      pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, old_extmark_id)
    else
      -- Extmark already exists, return it (don't recreate)
      return old_extmark_id
    end
  end

  -- Use default opts to let extmark naturally follow line changes
  local opts = {}

  local success, result = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, row, col, opts)

  if not success then
    vim.notify(string.format("[Tracker] Failed to create extmark: nvim_buf_set_extmark failed: %s",
      tostring(result)), vim.log.levels.WARN)
    return nil
  end

  if not result then
    vim.notify("[Tracker] Failed to create extmark: nvim_buf_set_extmark returned nil", vim.log.levels.WARN)
    return nil
  end

  -- Successfully created, now track it
  M.track_extmark(bufnr, bookmark_id, result)
  return result
end

---Clear all tracking for a buffer (called when buffer closes)
---@param bufnr number
function M.clear_buffer(bufnr)
  local buf_path = normalize_buf_path(bufnr)
  local prefix = buf_path .. ":"
  for key, _ in pairs(extmark_map) do
    if key:sub(1, #prefix) == prefix then
      extmark_map[key] = nil
    end
  end
end

---Get all tracked bookmarks for a buffer
---@param bufnr number Buffer number
---@return table<{bookmark_id: number, extmark_id: number}>
function M.get_buffer_bookmarks(bufnr)
  local buf_path = normalize_buf_path(bufnr)
  local result = {}
  local prefix = buf_path .. ":"

  for key, extmark_id in pairs(extmark_map) do
    if key:sub(1, #prefix) == prefix then
      local bookmark_id_str = key:sub(#prefix + 1)
      local bookmark_id = tonumber(bookmark_id_str)
      if bookmark_id then
        table.insert(result, {
          bookmark_id = bookmark_id,
          extmark_id = extmark_id,
        })
      end
    end
  end

  return result
end

---Get the raw extmark_map (for debugging)
---@return table
function M.get_extmark_map()
  return extmark_map
end

return M
