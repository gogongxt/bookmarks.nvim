local Repo = require("bookmarks.domain.repo")
local Service = require("bookmarks.domain.service")
local Node = require("bookmarks.domain.node")
local Actions = require("bookmarks.picker.actions")

local has_snacks, snacks = pcall(require, "snacks")
if not has_snacks then
  error("This picker requires snacks.nvim to be installed")
end

local M = {}

local function safe_string(str)
  if type(str) ~= "string" then
    return ""
  end
  return str
end

local function format_entry(bookmark, bookmarks)
  local name = ""
  local filename = ""
  local path = ""

  if bookmark then
    name = type(bookmark.name) == "string" and bookmark.name or ""
    if bookmark.location and type(bookmark.location.path) == "string" then
      filename = vim.fn.fnamemodify(bookmark.location.path, ":t") or ""
      path = vim.fn.pathshorten(bookmark.location.path) or ""
    end
  end

  -- Ensure all parts are valid strings before formatting
  return tostring(name) .. " │ " .. tostring(filename) .. " │ " .. tostring(path)
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
      -- Basic validation only
      if bookmark and bookmark.location and bookmark.location.path then
        -- Validate all string fields to prevent encoding errors
        local name = bookmark.name or ""
        local path = bookmark.location.path or ""

        -- Only process if all required strings are valid
        if type(name) == "string" and type(path) == "string" and path ~= "" then
          local entry_display = vim.g.bookmarks_config.picker.entry_display or format_entry
          local display = entry_display(bookmark, _bookmarks) or ""

          table.insert(items, {
            text = display,
            bookmark_id = bookmark.id,
            file = path,
            line = bookmark.location.line or 1,
            col = bookmark.location.col or 0,
          })
        end
      end
    end

    -- Create safe prompt
    local list_name = list and type(list.name) == "string" and list.name or "Unknown"
    local prompt = "Bookmarks in [" .. list_name .. "] "

    local picker_opts = {
      prompt = prompt,
      items = items,
      format = function(item)
        return { { tostring(item.text or "") } }
      end,
      preview = snacks.picker.preview.file,
      actions = {
        confirm = function(picker, item)
          if item and item.bookmark_id then
            require("bookmarks.domain.service").goto_bookmark(item.bookmark_id)
          end
        end,
        delete = function(picker)
          local selected_items = picker:selected({ fallback = true })
          if #selected_items > 0 then
            local selected = selected_items[1]
            if selected and selected.bookmark_id then
              -- Delete the bookmark using the service
              require("bookmarks.domain.service").delete_node(selected.bookmark_id)

              -- Restart the picker with a slight delay
              local opts = picker.opts
              picker:close()
              vim.defer_fn(function()
                M.pick_bookmark(nil, { prompt = opts.prompt })
              end, 50)
            end
          end
        end,
        open_split = function(picker)
          local selected_items = picker:selected({ fallback = true })
          if #selected_items > 0 then
            local selected = selected_items[1]
            if selected and selected.bookmark_id then
              require("bookmarks.domain.service").goto_bookmark(selected.bookmark_id, { cmd = "split" })
            end
          end
        end,
        open_vsplit = function(picker)
          local selected_items = picker:selected({ fallback = true })
          if #selected_items > 0 then
            local selected = selected_items[1]
            if selected and selected.bookmark_id then
              require("bookmarks.domain.service").goto_bookmark(selected.bookmark_id, { cmd = "vsplit" })
            end
          end
        end,
        open_tab = function(picker)
          local selected_items = picker:selected({ fallback = true })
          if #selected_items > 0 then
            local selected = selected_items[1]
            if selected and selected.bookmark_id then
              require("bookmarks.domain.service").goto_bookmark(selected.bookmark_id, { cmd = "tabnew" })
            end
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
