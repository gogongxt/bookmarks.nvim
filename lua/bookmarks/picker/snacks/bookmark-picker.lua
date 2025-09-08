local Repo = require("bookmarks.domain.repo")
local Service = require("bookmarks.domain.service")
local Node = require("bookmarks.domain.node")
local Actions = require("bookmarks.picker.actions")

local has_snacks, snacks = pcall(require, "snacks")
if not has_snacks then
  error("This picker requires snacks.nvim to be installed")
end

local M = {}

local function format_entry(bookmark, bookmarks)
  -- Calculate widths from all bookmarks
  local max_name = 15     -- minimum width
  local max_filename = 20 -- minimum width
  local max_filepath = 20 -- minimum width

  for _, bm in ipairs(bookmarks) do
    max_name = math.max(max_name, #bm.name)
    local filename = vim.fn.fnamemodify(bm.location.path, ":t")
    local path = vim.fn.pathshorten(bm.location.path)
    max_filename = math.max(max_filename, #filename)
    max_filepath = math.max(max_filepath, #path)
  end

  -- Apply maximum constraints
  max_name = math.min(max_name, 30)
  max_filename = math.min(max_filename, 30)
  max_filepath = math.min(max_filepath, 40)

  -- Format current bookmark entry
  local name = bookmark.name
  local filename = vim.fn.fnamemodify(bookmark.location.path, ":t")
  local path = vim.fn.pathshorten(bookmark.location.path)

  -- Pad or truncate name
  if #name > max_name then
    name = name:sub(1, max_name - 2) .. ".."
  else
    name = name .. string.rep(" ", max_name - #name)
  end

  -- Pad or truncate filename
  if #filename > max_filename then
    filename = filename:sub(1, max_filename - 2) .. ".."
  else
    filename = filename .. string.rep(" ", max_filename - #filename)
  end

  -- Pad or truncate path
  if #path > max_filepath then
    path = path:sub(1, max_filepath - 2) .. ".."
  else
    path = path .. string.rep(" ", max_filepath - #path)
  end

  return string.format("%s │ %s │ %s", name, filename, path)
end

---Pick a *bookmark* then call the callback function against it
---e.g.
---:lua require("bookmarks.picker.snacks.bookmark-picker").pick_bookmark(function(bookmark) vim.print(bookmark.name) end)
---@param callback fun(bookmark: Bookmarks.Node): nil
---@param opts? {prompt?: string, bookmarks?: Bookmarks.Node[]}
function M.pick_bookmark(callback, opts)
  opts = opts or {}

  local function start_picker(_bookmarks, list)
    -- Convert bookmarks to snacks picker items
    local items = {}
    for _, bookmark in ipairs(_bookmarks) do
      local entry_display = vim.g.bookmarks_config.picker.entry_display or format_entry
      local display = entry_display(bookmark, _bookmarks)
      table.insert(items, {
        text = display,
        bookmark = bookmark,
        file = bookmark.location.path,
        lnum = bookmark.location.line,
        col = bookmark.location.col,
        pos = { bookmark.location.line, bookmark.location.col },
        -- Add location info for line-specific preview
        loc = {
          range = {
            ["start"] = {
              line = bookmark.location.line - 1, -- 0-indexed for LSP
              character = bookmark.location.col,
            },
            ["end"] = {
              line = bookmark.location.line - 1, -- 0-indexed for LSP
              character = bookmark.location.col,
            },
          },
        },
      })
    end

    local picker_opts = {
      prompt = opts.prompt or ("Bookmarks in [" .. list.name .. "] "),
      items = items,
      format = function(item)
        return { { item.text } }
      end,
      preview = snacks.picker.preview.file,
      actions = {
        confirm = "jump",
        delete = function(picker)
          local selected_items = picker:selected({ fallback = true })
          local current_cursor = picker.list.cursor
          if #selected_items > 0 then
            local selected = selected_items[1]
            -- Call the shared actions module to handle deletion
            require("bookmarks.picker.actions").delete(picker, selected)
            -- Restart the picker with a slight delay to allow UI to update
            local opts = picker.opts
            picker:close()
            vim.defer_fn(function()
              M.pick_bookmark(nil, { prompt = opts.prompt })
              -- Restore cursor position after picker restarts
              vim.defer_fn(function()
                local picker_win = vim.api.nvim_get_current_win()
                local buf = vim.api.nvim_win_get_buf(picker_win)
                if vim.api.nvim_buf_is_valid(buf) then
                  vim.api.nvim_win_set_cursor(
                    picker_win,
                    { math.min(current_cursor, vim.api.nvim_buf_line_count(buf)), 0 }
                  )
                end
              end, 50)
            end, 50)
          else
            -- If no item is selected, use the current target
            local current_item = picker.list:get_target()
            if current_item then
              require("bookmarks.picker.actions").delete(picker, current_item)
              -- Restart the picker with a slight delay to allow UI to update
              local opts = picker.opts
              picker:close()
              vim.defer_fn(function()
                M.pick_bookmark(nil, { prompt = opts.prompt })
                -- Restore cursor position after picker restarts
                vim.defer_fn(function()
                  local picker_win = vim.api.nvim_get_current_win()
                  local buf = vim.api.nvim_win_get_buf(picker_win)
                  if vim.api.nvim_buf_is_valid(buf) then
                    vim.api.nvim_win_set_cursor(
                      picker_win,
                      { math.min(current_cursor, vim.api.nvim_buf_line_count(buf)), 0 }
                    )
                  end
                end, 50)
              end, 50)
            end
          end
        end,
        open_split = function(picker)
          local selected_items = picker:selected({ fallback = true })
          if #selected_items > 0 then
            local selected = selected_items[1]
            -- Call the shared actions module
            require("bookmarks.picker.actions").open_in_split(picker, selected)
            -- No need to close, actions will handle navigation
          end
        end,
        open_vsplit = function(picker)
          local selected_items = picker:selected({ fallback = true })
          if #selected_items > 0 then
            local selected = selected_items[1]
            -- Call the shared actions module
            require("bookmarks.picker.actions").open_in_vsplit(picker, selected)
            -- No need to close, actions will handle navigation
          end
        end,
        open_tab = function(picker)
          local selected_items = picker:selected({ fallback = true })
          if #selected_items > 0 then
            local selected = selected_items[1]
            -- Call the shared actions module
            require("bookmarks.picker.actions").open_in_new_tab(picker, selected)
            -- No need to close, actions will handle navigation
          end
        end,
      },
      win = {
        input = {
          keys = {
            ["<CR>"] = { "confirm", mode = { "n", "i" } },
            ["<C-d>"] = { "delete", mode = { "n", "i" } },
            ["<C-x>"] = { "open_split", mode = { "n", "i" } },
            ["<C-v>"] = { "open_vsplit", mode = { "n", "i" } },
            ["<C-t>"] = { "open_tab", mode = { "n", "i" } },
          },
        },
        list = {
          keys = {
            ["<CR>"] = "confirm",
            ["<C-d>"] = "delete",
            ["<C-x>"] = "open_split",
            ["<C-v>"] = "open_vsplit",
            ["<C-t>"] = "open_tab",
          },
        },
        preview = {
          keys = {
            ["<CR>"] = "confirm",
            ["<2-LeftMouse>"] = "confirm",
            ["<C-d>"] = "delete",
            ["<C-x>"] = "open_split",
            ["<C-v>"] = "open_vsplit",
            ["<C-t>"] = "open_tab",
          },
        },
      },
    }

    snacks.picker(picker_opts)
  end

  if opts.bookmarks then
    start_picker(opts.bookmarks, { name = "Custom Selection" })
  else
    local active_list = Repo.ensure_and_get_active_list()
    start_picker(Node.get_all_bookmarks(active_list), active_list)
  end
end

---Grep through the content of all bookmarked files
---@param opts? table
function M.grep_bookmark(opts)
  opts = opts or {}
  local active_list = Repo.ensure_and_get_active_list()
  local bookmarks = Node.get_all_bookmarks(active_list)

  -- Get unique file paths from bookmarks
  local files = {}
  local seen = {}
  for _, bookmark in ipairs(bookmarks) do
    if not seen[bookmark.location.path] then
      seen[bookmark.location.path] = true
      table.insert(files, bookmark.location.path)
    end
  end

  -- Use snacks grep picker
  snacks.picker(
    "grep",
    vim.tbl_extend("force", {
      prompt = "Grep Bookmarked Files",
      search_dirs = files,
    }, opts)
  )
end

return M
